import options
import tables

import Message as MessageFile

type
  RecordKind* = enum
    OfferRecord,   #An offer we have for the offer party.
    RequestRecord, #A request for something we want from the other party.
    MessageRecord  #A response to a request from the other party.

  Record* = ref object
    kind*: RecordKind
    count*: int
    epoch*: int
    #This is an Option for two reasons.
    #1) To signify that there may not be a message attached.
    #2) So if a message is ever improperly attached/not attached, we cause a fatal error.
    message*: Option[Message]

  State* = ref object
    interactive: bool
    epoch: int
    when defined(MVDS_TESTS):
      messages*: Table[seq[byte], Record]
    else:
      messages: Table[seq[byte], Record]

proc newState*(interactive: bool): State {.inline.} =
  State(
    interactive: interactive,
    epoch: 0,
    messages: initTable[seq[byte], Record]()
  )

#Offer a new message to this peer.
proc offer*(state: State, msg: Message, epoch: int) {.inline.} =
  state.messages[msg.id] = Record(
    kind: if state.interactive: OfferRecord else: MessageRecord,
    count: 0,
    epoch: epoch,
    message: some(msg)
  )

#Returns false if the message has already finished.
proc updateEpoch*(state: State, msgID: seq[byte], epoch: int): bool =
  if state.messages.hasKey(msgID):
    state.messages[msgID].epoch = epoch
    return true

#Handle a new Payload and generate the next one.
proc handle*(state: State, incoming: Payload): Payload =
  #Handle acks.
  for ack in incoming.acks:
    state.messages.del(ack)

  #Handle offers.
  #All we need to create matching requests.
  for offer in incoming.offers:
    state.messages[offer] = Record(
      kind: RequestRecord,
      count: 0,
      epoch: state.epoch + 1
    )

  #Handle requests.
  #We need to update our existing offer, if it exists, to a Message.
  for req in incoming.requests:
    if not state.messages.hasKey(req):
      continue
    state.messages[req] = Record(
      kind: MessageRecord,
      count: 0,
      epoch: state.epoch + 1,
      message: state.messages[req].message
    )

  #Handle messages.
  #We need to remove our matching requests and create the ack.
  result.acks = newSeq[seq[byte]](incoming.messages.len)
  for m in 0 ..< incoming.messages.len:
    result.acks[m] = incoming.messages[m].id
    state.messages.del(incoming.messages[m].id)

  #Generate offers, requests, and messages.
  var
    o: int = 0
    r: int = 0
    m: int = 0
  result.offers.setLen(state.messages.len)
  result.requests.setLen(state.messages.len)
  result.messages.setLen(state.messages.len)

  for msg in state.messages.keys():
    var record: Record = state.messages[msg]
    #Only transmit this message if it's the first time or its time to retransmit it again.
    if (record.count != 0) and (record.epoch > state.epoch):
      continue
    #Increment the count.
    inc(record.count)

    case record.kind:
      of OfferRecord:
        result.offers[o] = msg
        inc(o)
      of RequestRecord:
        result.requests[r] = msg
        inc(r)
      of MessageRecord:
        result.messages[m] = record.message.get()
        inc(m)

  result.offers.setLen(o)
  result.requests.setLen(r)
  result.messages.setLen(m)

  inc(state.epoch)

when defined MVDS_TESTS:
  proc `==`*(lhs: Record, rhs: Record): bool {.inline.} =
    (
      (lhs.kind == rhs.kind) and
      (lhs.count == rhs.count) and
      (lhs.epoch == rhs.epoch) and
      (
        (lhs.message.isNone() and rhs.message.isNone()) or
        (
          lhs.message.isSome() and
          rhs.message.isSome() and
          (lhs.message.get() == rhs.message.get())
        )
      )
    )
