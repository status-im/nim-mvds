import random
import times
import options
import tables
import unittest

import ../mvds
import../mvds/State

suite "Interactive":
  randomize(getTime().toUnix())

  setup:
    var
      alice: MVDSNode = newMVDSNode(true)
      bob: MVDSNode = newMVDSNode(true)
      res: tuple[messages: seq[Message], response: seq[byte]]

  test "Nothing":
    check alice.handle(@[]) == res

  test "Single message":
    var
      groupID: seq[byte] = newSeq[byte](rand(100))
      body: seq[byte] = newSeq[byte](rand(500))
    for i in 0 ..< groupID.len:
      groupID[i] = byte(rand(255))
    for i in 0 ..< body.len:
      body[i] = byte(rand(255))

    var msg: Message = newMessage(groupID, body)
    alice.offer(msg, 0)
    res = alice.handle(@[])
    check:
      res.messages.len == 0
      alice.state.messages.len == 1
      alice.state.messages.hasKey(msg.id)

      alice.state.messages[msg.id] == Record(
        kind: OfferRecord,
        count: 1,
        epoch: 0,
        message: some(msg)
      )

    res = bob.handle(res.response)
    check:
      res.messages.len == 0
      bob.state.messages.len == 1
      bob.state.messages.hasKey(msg.id)

      bob.state.messages[msg.id] == Record(
        kind: RequestRecord,
        count: 1,
        epoch: 1,
        message: none(Message)
      )

    res = alice.handle(res.response)
    check:
      res.messages.len == 0
      alice.state.messages.len == 1
      alice.state.messages.hasKey(msg.id)

      alice.state.messages[msg.id] == Record(
        kind: MessageRecord,
        count: 1,
        epoch: 2,
        message: some(msg)
      )

    res = bob.handle(res.response)
    check:
      res.messages.len == 1
      res.messages[0] == msg
      bob.state.messages.len == 0

    res = alice.handle(res.response)
    check:
      alice.handle(res.response) == (messages: @[], response: @[])
      alice.state.messages.len == 0
