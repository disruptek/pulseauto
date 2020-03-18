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
import std/os
import std/json

import cligen

import dbus
import dbus/lowlevel

{.experimental: "dotOperators".}
{.experimental: "callOperator".}

type
  Interface* = object
    bus*: Bus
    path*: ObjectPath
    name*: string
    service*: string

  Method* = object
    iface*: Interface
    name*: string

const
  lookupPath = ObjectPath"/org/pulseaudio/server_lookup1"

proc getBus*(path: DBusValue): Bus =
  ## open a new bus connection at the given address
  var
    error: ptr DBusError
  let
    path = path.stringValue
    conn = dbus_connection_open(path.cstring, error)
  if conn == nil:
    echo "unable to connect"
    quit(1)
  if error != nil:
    echo error.repr
    quit(1)
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
    result = newJInt(value.byteValue.int)
  of dtVariant:
    result = value.variantValue.toJson
  else:
    result = newJNull()

converter toBool(b: dbus_bool_t): bool =
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

proc toString*(value: DBusValue): string =
  ## turn an array of bytes ending in zero into a string
  for element in value.arrayValue:
    if element.byteValue == 0:
      break
    else:
      result.add element.byteValue.char

proc `$`*(iface: Interface): string = result = iface.name
proc `$`*(sig: Signature): string = result = sig.string
proc `$`*(path: ObjectPath): string = result = path.string

proc `$`(value: DBusValue): string =
  result = case value.kind
  of dtString:
    value.stringValue
  of dtObjectPath:
    value.objectPathValue.string
  of dtSignature:
    value.signatureValue.string
  else:
    dbus.`$`(value)

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
    iface = Interface(bus: getBus(DBUS_BUS_SESSION),
                      service: "org.pulseaudio.Server",
                      path: path,
                      name: "org.freedesktop.DBus.Properties")
  result = iface{"Get"}("org.PulseAudio.ServerLookup1", "Address")

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

when isMainModule:
  let
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
    echo "client:", client.path
    # now we'll issue some calls on the client's interface
    let
      getr = client{"Get"}
      props = getr($client, "PropertyList")
    # iterate over the properties; it's basically a dictionary
    for key, val in props.pairs:
      # but the values are arrays of bytes terminated by a 0
      # so turn that shit into a string
      let
        value = val.toString
      # dump it out
      echo "\t", key, " -> ", value
      if key == "application.process.binary":
        # if it looks like it produces music
        if value in ["pianobar", "mpd"]:
          # iterate over the client's streams
          for path in getr($client, "PlaybackStreams"):
            echo "\t stream:", path
            # address a stream interface that is a child of Core1
            var
              stream = client.peer(core1.name & "." & "Stream")
            # point at the path of the playback stream we found
            stream.path = ObjectPath($path)
            # set the volume on that stream to 25_000 / 65_535
            # provide multiple values in the variant array to
            # set the volumes of multiple channels at once
            discard stream{"Set"}($stream, "Volume",
                                  newVariant[seq[uint32]](@[25_000.uint32]))
