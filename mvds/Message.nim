import times

import stew/endians2
import nimcrypto
import protobuf_serialization

#Shim until https://github.com/status-im/nim-protobuf-serialization/pull/5 is merged.
when not defined(protobuf3):
  template protobuf3() {.pragma.}

type
  Message* {.protobuf3.} = ref object
    group* {.fieldNumber: 1.}: seq[byte] #Assigned into a group by developer, not protocol.
    time* {.pint, fieldNumber: 2.}: int64
    body* {.fieldNumber: 3.}: seq[byte]
    id {.dontSerialize.}: seq[byte]

  Payload* {.protobuf3.} = object
    acks* {.fieldNumber: 1.}: seq[seq[byte]]
    offers* {.fieldNumber: 2.}: seq[seq[byte]]
    requests* {.fieldNumber: 3.}: seq[seq[byte]]
    messages* {.fieldNumber: 4.}: seq[Message]

proc id*(msg: Message): seq[byte] =
  if msg.id.len == 0:
    msg.id = @(
      sha256.digest(
        cast[seq[byte]]("MESSAGE_ID") &
        msg.group &
        @(uint64(msg.time).toBytesLE()) &
        msg.body
      ).data
    )
  result = msg.id

proc newMessage*(group: seq[byte], body: seq[byte], time: int64 = getTime().toUnix()): Message {.inline.} =
  Message(
    group: group,
    time: time,
    body: body
  )

when defined MVDS_TESTS:
  proc `==`*(lhs: Message, rhs: Message): bool {.inline.} =
    (lhs.group == rhs.group) and
    (lhs.time == rhs.time) and
    (lhs.body == rhs.body)
