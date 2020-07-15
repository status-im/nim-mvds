import times

import stew/endians2
import nimcrypto
import protobuf_serialization

type
  Message* = ref object
    group* {.fieldNumber: 1.}: seq[byte] #Assigned into a group by developer, not protocol.
    time* {.pint, fieldNumber: 2.}: int64
    body* {.fieldNumber: 3.}: seq[byte]
    id* {.dontSerialize.}: seq[byte]

  Payload* = object
    acks* {.fieldNumber: 1.}: seq[seq[byte]]
    offers* {.fieldNumber: 2.}: seq[seq[byte]]
    requests* {.fieldNumber: 3.}: seq[seq[byte]]
    messages* {.fieldNumber: 4.}: seq[Message]

proc hash*(msg: Message) =
  msg.id = @(
    sha256.digest(
      cast[seq[byte]]("MESSAGE_ID") &
      msg.group &
      @(uint64(msg.time).toBytesLE()) &
      msg.body
    ).data
  )

proc newMessage*(group: seq[byte], body: seq[byte]): Message =
  result = Message(
    group: group,
    time: getTime().toUnix(),
    body: body
  )
  result.hash()

when defined MVDS_TESTS:
  proc `==`*(lhs: Message, rhs: Message): bool {.inline.} =
    (
      (lhs.group == rhs.group) and
      (lhs.time == rhs.time) and
      (lhs.body == rhs.body) and
      (lhs.id == rhs.id)
    )
