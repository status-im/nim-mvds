import random
import times
import options
import tables
import unittest

import ../mvds
import../mvds/State

suite "Batch":
  randomize(getTime().toUnix())

  setup:
    var
      alice: MVDSNode = newMVDSNode(false)
      bob: MVDSNode = newMVDSNode(false)
      res: tuple[messages: seq[Message], response: Payload]
    var
      groupID: seq[byte] = newSeq[byte](rand(100))
      body: seq[byte] = newSeq[byte](rand(500))
    for i in 0 ..< groupID.len:
      groupID[i] = byte(rand(255))
    for i in 0 ..< body.len:
      body[i] = byte(rand(255))
    var msg: Message = newMessage(groupID, body)

  test "Nothing":
    check alice.handle(Payload()) == res

  test "Single message":
    alice.offer(msg, 0)
    res = alice.handle(Payload())
    check:
      res.messages.len == 0
      alice.state.messages.len == 1
      alice.state.messages.hasKey(msg.id)

      alice.state.messages[msg.id] == Record(
        kind: MessageRecord,
        count: 1,
        epoch: 0,
        message: some(msg)
      )

    res = bob.handle(res.response)
    check:
      res.messages.len == 1
      res.messages[0] == msg
      bob.state.messages.len == 0

    check:
      alice.handle(res.response) == (messages: @[], response: Payload())
      alice.state.messages.len == 0

  test "No ack":
    alice.offer(msg, 0)
    var origRes: tuple[messages: seq[Message], response: Payload] = alice.handle(Payload())
    for i in 2 ..< 7:
      res = alice.handle(Payload())
      check:
        res == origRes
        res.messages.len == 0
        alice.state.messages.len == 1
        alice.state.messages.hasKey(msg.id)

        alice.state.messages[msg.id] == Record(
          kind: MessageRecord,
          count: i,
          epoch: 0,
          message: some(msg)
        )

  test "Epoch manipulation":
    alice.offer(msg, 0)
    var origRes: tuple[messages: seq[Message], response: Payload] = alice.handle(Payload())
    check alice.updateEpoch(msg.id, 7)
    for i in 1 ..< 7:
      res = alice.handle(Payload())
      check:
        res.messages.len == 0
        res.response == Payload()
        alice.state.messages.len == 1
        alice.state.messages.hasKey(msg.id)

        alice.state.messages[msg.id] == Record(
          kind: MessageRecord,
          count: 1,
          epoch: 7,
          message: some(msg)
        )

    check:
      alice.handle(Payload()) == origRes
      alice.state.messages.len == 1

    discard alice.handle(bob.handle(origRes.response).response)
    check:
      alice.state.messages.len == 0
      not alice.updateEpoch(msg.id, 9)
