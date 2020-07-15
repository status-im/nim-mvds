import protobuf_serialization

import mvds/Message
export Message

import mvds/State

type MVDSNode* = ref object
  when defined(MVDS_TESTS):
    state*: State
  else:
    state: State

proc newMVDSNode*(interactive: bool): MVDSNode {.inline.} =
  MVDSNode(
    state: newState(interactive)
  )

proc offer*(node: MVDSNode, msg: Message, epoch: int) {.inline.} =
  node.state.offer(msg, epoch)

proc updateEpoch*(node: MVDSNode, msgID: seq[byte], epoch: int): bool =
  node.state.updateEpoch(msgID, epoch)

proc handle*(node: MVDSNode, msg: seq[byte]): tuple[messages: seq[Message], response: seq[byte]] =
  var payload: Payload = Protobuf.decode(msg, Payload)
  for msg in payload.messages:
    msg.hash()
  return (payload.messages, Protobuf.encode(node.state.handle(payload)))
