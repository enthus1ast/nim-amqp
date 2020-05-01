## 
## Tests for the `basic` module
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_amqp/field_table
import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/channel
import nim_amqp/classes/connection
import nim_amqp/classes/exchange
import nim_amqp/classes/queue
import nim_amqp/classes/basic


const exchName = "queue-tests-exchange"
const channelNum = 1
let conn = newAMQPConnection("localhost", "guest", "guest")
conn.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen("/")

let chan = conn.newAMQPChannel(number=channelNum, frames.handleFrame, frames.sendFrame)
chan.channelOpen()

chan.exchangeDeclare(exchName, "direct", false, true, false, false, false, FieldTable(), channelNum)


suite "AMQP Basic tests":
    test "Can set QoS parameters":
        chan.basicQos(256, false, channelNum)

    test "Can start a consumer":
        let qName = "unit-test-basic-consume"
        chan.queueDeclare(qName, false, true, false, true, false, FieldTable(), channelNum)
        chan.basicConsume(qName, "", false, false, false, false, FieldTable(), channelNum)

    test "Can cancel a consumer":
        let qName = "unit-test-basic-consume-cancel"
        chan.queueDeclare(qName, false, true, false, true, false, FieldTable(), channelNum)
        chan.basicConsume(qName, "consumer-cancel-test", false, false, false, false, FieldTable(), channelNum)
        chan.basicCancel("consumer-cancel-test", false, channelNum)

chan.exchangeDelete("queue-tests-exchange", false, false, channelNum)
chan.channelClose()
chan.connectionClose()