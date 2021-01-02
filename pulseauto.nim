##[

the goal:
  - have a way to set levels on client streams by specifying the
    application name and/or pid

use-case:
  - setup audio for streaming so that the mumble folks can be heard
    over the music, the music can heard, i can be heard, and the
    normal desktop audio is at a reasonable level



]##
import std/sequtils
import std/strutils
import std/os
import std/json
import std/logging
import std/nre

import cligen

import dbus
import dbus/lowlevel

when defined(pulseautoWrapper):
  import wrapper

{.experimental: "dotOperators".}
{.experimental: "callOperator".}

const
  lookupPath = ObjectPath"/org/pulseaudio/server_lookup1"
  nominalHead = uint32 65535
  maxLevel = uint32(nominalHead.float * 1.5)

type
  Interface* = object
    bus*: Bus
    path*: ObjectPath
    name*: string
    service*: string

  Method* = object
    iface*: Interface
    name*: string

  LevelKind = enum
    Ratio
    Raw
    Percent

  Level = object
    case kind: LevelKind
    of Ratio:
      ratio: range[0.0'f32 .. 3.0'f32]
    of Percent:
      percent: range[0'u32 .. 150'u32]
    of Raw:
      raw: range[0'u32 .. maxLevel]

proc `$`(err: ptr DBusError): string =
  "$#: $#" % [ $err[].name, $err[].message ]

proc getBus*(path: DBusValue): Bus =
  ## open a new bus connection at the given address
  var
    error: ptr DBusError
  let
    path = path.stringValue
    conn = dbus_connection_open(path.cstring, error)
  if conn == nil:
    error "unable to connect via " & path
  elif error != nil:
    error $error
  else:
    result = Bus(conn: conn)

proc toJson*(value: DbusValue): JsonNode =
  case value.kind
  of dtArray:
    result = newJArray()
    for v in mapIt(value.arrayValue, it.toJson):
      result.add v
  of dtBool:
    result = newJBool(value.boolValue)
  of dtDictEntry:
    result = newJArray()
    result.add value.dictKey.toJson
    result.add value.dictValue.toJson
  of dtDouble:
    result = newJFloat(value.doubleValue)
  of dtSignature:
    result = newJString(value.signatureValue.string)
  of dtUnixFd:
    result = newJInt(value.fdValue.int)
  of dtInt32:
    result = newJInt(value.int32Value)
  of dtInt16:
    result = newJInt(value.int16Value)
  of dtObjectPath:
    result = newJString(value.objectPathValue.string)
  of dtUint16:
    result = newJInt(value.uint16Value.int)
  of dtString:
    result = newJString(value.stringValue)
  of dtStruct:
    result = newJArray()
    for v in mapIt(value.structValues, it.toJson):
      result.add v
  of dtUint64:
    result = newJInt(value.uint64Value.int)
  of dtUint32:
    result = newJInt(value.uint32Value.int)
  of dtInt64:
    result = newJInt(value.int64Value)
  of dtByte:
    result = newJString("" & value.byteValue.char)
  of dtVariant:
    result = value.variantValue.toJson
  else:
    result = newJNull()

converter toBool*(b: dbus_bool_t): bool =
  result = cast[uint32](b) == 1

template queryBusImpl(meth: Method; args: typed): untyped =
  var
    msg = makeCall(meth.iface.service,
                   meth.iface.path, meth.iface.name, meth.name)
  for value in args.items:
    msg.append(value)
  let
    pending = meth.iface.bus.sendMessageWithReply(msg)
    reply = pending.waitForReply()
  reply.raiseIfError
  try:
    var
      iter = reply.iterate()
    result = iter.unpackCurrent(DBusValue)
  except DBusException: # i hate it
    result = asDbusValue(nil)

proc queryBus(meth: Method; args: varargs[DBusValue, asDbusValue]): DBusValue =
  queryBusImpl(meth, args)

proc queryBus(meth: Method; args: seq[DBusValue]): DBusValue =
  queryBusImpl(meth, args)

proc peer*(iface: Interface; name: string): Interface =
  ## yield the adjacent interface with the given name
  # Interface(name: name, path: iface.path, bus: iface.bus)
  result = iface
  result.name = name

iterator items*(value: DBusValue): DBusValue =
  case value.kind
  of dtArray:
    for item in value.arrayValue.items:
      yield item
  else:
    raise newException(OSError, $value)

iterator pairs*(value: DBusValue): tuple[key: DBusValue; val: DBusValue] =
  case value.kind
  of dtArray:
    if value.arrayValueType.kind != dtDictEntry:
      raise newException(ValueError, "not a dictionary")
    for pair in value.items:
      yield (key: pair.dictKey, val: pair.dictValue)
  else:
    raise newException(OSError, $value)

proc toCstring(value: DBusValue): cstring =
  assert value.kind == dtArray
  #assert value.arrayValueType == dtByte, "obj versus enum... fite!"
  assert value.arrayValueType.kind == dtByte, $value.arrayValueType
  result = cast[cstring](alloc(sizeof(char) * len(value.arrayValue)))
  for i, v in value.arrayValue.pairs:
    result[i] = v.byteValue.char
    if v.byteValue.char == '\0':
      break

proc `$`*(iface: Interface): string = result = iface.name
proc `$`*(sig: Signature): string = result = sig.string
proc `$`*(path: ObjectPath): string = result = path.string

proc `$`(value: DBusValue): string =
  case value.kind
  of dtString:
    result = value.stringValue
  of dtObjectPath:
    result = value.objectPathValue.string
  of dtSignature:
    result = value.signatureValue.string
  of dtDictEntry:
    result = $value.dictKey & ": " & $value.dictValue
  of dtUint64:
    result = $value.uint64Value
  of dtUint32:
    result = $value.uint32Value.uint64
  of dtUint16:
    result = $value.uint16Value
  of dtInt16:
    result = $value.int16Value
  of dtInt32:
    result = $value.int32Value
  of dtInt64:
    result = $value.int64Value
  of dtBool:
    result = $value.boolValue
  of dtNull:
    result = "💣"
  of dtArray:
    case value.arrayValueType.kind
    of dtByte:
      # it's basically a cstring
      result.add quoteShell($toCstring(value))
    of dtDictEntry:
      result.add "{\n"
      result.add mapIt(value.arrayValue, "\t\t\t" & $it).join(",\n")
      result.add "\n}"
    else:
      result = "[ "
      result.add mapIt(value.arrayValue, $it).join(", ")
      result.add " ]"
  else:
    result = dbus.`$`(value)

proc `==`(value: DBusValue; s: string): bool =
  if value.kind notin {dtString, dtObjectPath, dtSignature}:
    raise newException(ValueError, "bad value type: " & $value.kind)
  result = system.`==`($value, s)

proc `..`(a: Interface): Interface =
  ## parent interface
  result = a
  result.name = changeFileExt($a, "")
  if result.name.len == a.name.len:
    raise newException(Defect, "already at top level")

proc `..`(a: Interface; name: string): Interface =
  ## named peer interface
  result = a
  result.name = changeFileExt($a, "") & "." & name

proc `[]`*(iface: Interface; name: string): Method =
  ## get a method on the interface by name
  result = Method(iface: iface, name: name)

proc `path=`(iface: var Interface; path: ObjectPath) =
  ## switch to different path
  system.`=`(iface.path, path)

proc `path=`(iface: var Interface; path: string) =
  ## switch to different path
  system.`=`(iface.path, path.ObjectPath)

proc `path=`(iface: var Interface; path: DBusValue) =
  ## switch to different path
  system.`=`(iface.path, path.stringValue.ObjectPath)

proc `{}`*(iface: Interface; name: string): Method =
  ## fetch a method from the interface's org.freedesktop.DBus.Properties peer
  result = iface.peer("org.freedesktop.DBus.Properties")[name]

proc `/`*(iface: Interface, name: string): Interface =
  ## interface at child path
  var
    child = iface
  child.path = ObjectPath(child.path.string / name)
  result = child

proc `()`*(meth: Method; args: varargs[DBusValue, asDBusValue]): DBusValue =
  ## call a method with arbitrary arguments
  queryBusImpl(meth, args)

proc `.`(iface: Interface, name: string): Interface =
  ## child interface
  result = iface
  result.name &= "." & name

when false:
  proc `()`(path: var ObjectPath; args: varargs[string, `$`]) =
    var
      arguments: seq[string]
    for a in args.items:
      arguments.add a
    path = joinPath(args)

proc getPulseServerAddress*(path = lookupPath): DBusValue =
  let
    bus = getBus(DBUS_BUS_SESSION)
  if bus == nil:
    result = asDbusValue(nil)
  else:
    let
      iface = Interface(bus: bus, service: "org.pulseaudio.Server",
                        path: path, name: "org.freedesktop.DBus.Properties")
    result = iface{"Get"}("org.PulseAudio.ServerLookup1", "Address")
  when not defined(release):
    echo $result

proc parseLevel(input: string): Level =
  ## parse a level from a string
  if input.endsWith "%":
    result = Level(kind: Percent, percent: uint32 input[0 .. ^2].parseInt)
  elif input.contains ".":
    result = Level(kind: Ratio, ratio: float32 input.parseFloat)
  else:
    result = Level(kind: Raw, raw: uint32 input.parseInt)

proc parseLevel(value: DBusValue): Level =
  ## parse the first channel
  for channel in value.items:
    result = Level(kind: Raw, raw: channel.uint32Value)
    break

proc renderLevel(level: Level; versus: Level): uint32 =
  case level.kind
  of Percent:
    result = uint32 (nominalHead.float32 * level.percent.float32 / 100'f32)
  of Ratio:
    result = uint32 (versus.raw.float32 * level.ratio)
  of Raw:
    result = level.raw

proc setVolume(stream: Interface; level: Level) =
  var
    versus: Level
  case level.kind
  of Ratio:
    versus = parseLevel(stream{"Get"}($stream, "Volume"))
  else:
    versus = Level(kind: Raw, raw: maxLevel)
  let
    rendered = renderLevel(level, versus)
    volume = newVariant[seq[uint32]](@[rendered])
  discard stream{"Set"}($stream, "Volume", volume)

proc pulseauto*(level: string; client = "(mpd|pianobar)";
                key = ""; value = "";
                property = "application\\.process\\.binary") =
  let
    level = parseLevel(level)
    property = re(property)
    rx = re(client)
    keyrx = re(if key == "": "." else: key)
    valuerx = re(if value == "": "." else: value)
    address = getPulseServerAddress()
    core1 = Interface(bus: getBus(address),
                      path: ObjectPath"/org/pulseaudio/core1",
                      service: "org.pulseaudio.Server",
                      name: "org.PulseAudio.Core1")

  # get the clients at the pulseaudio service; the Core1 interface
  for path in core1{"Get"}($core1, "Clients"):
    var
      client = core1
    # reset the path and interface name
    client.path = path.objectPathValue
    client.name = core1.name & "." & "Client"
    debug "client: ", client.path
    # now we'll issue some calls on the client's interface
    let
      getr = client{"Get"}
      props = getr($client, "PropertyList")
    # iterate over the properties; it's basically a dictionary
    for key, val in props.pairs:
      # but the values are arrays of bytes terminated by a 0
      # so turn that shit into a string
      debug "\to ", $key, " -> ", $val
      if property in $key and rx in $val:
        # iterate over the client's streams
        for category in ["RecordStreams", "PlaybackStreams"]:
          for path in getr($client, category):
            if path.kind == dtObjectPath:
              debug "\t stream:", path.kind, $path
              # address a stream interface that is a child of Core1
              var
                stream = client.peer(core1.name & "." & "Stream")
              # point at the path of the playback stream we found
              stream.path = ObjectPath($path)
              case category
              of "RecordStreams":
                let
                  device = stream{"Get"}($stream, "Device")
                when true:
                  assert device.kind == dtObjectPath
                  var
                    dev = client.peer(core1.name & "." & "Device")
                  dev.path = ObjectPath($device)
                when true:
                  let
                    pros = dev{"GetAll"}($dev)
                  for key, val in pros.pairs:
                    debug "\t\t.", key, " -> ", val
                    if keyrx in $key:
                      if valuerx in $val:
                        echo "BINGO"
                        when false:
                          stream.setVolume(level)
              of "PlaybackStreams":
                # set the volume on that stream to 25_000 / 65_535
                # provide multiple values in the variant array to
                # set the volumes of multiple channels at once
                stream.setVolume(level)

when isMainModule:
  when defined(release) or defined(danger):
    let level = lvlWarn
  else:
    let level = lvlAll
  let logger = newConsoleLogger(useStderr=true, levelThreshold=level)
  addHandler(logger)

  dispatch pulseauto
