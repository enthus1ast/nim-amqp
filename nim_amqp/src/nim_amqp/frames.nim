## 
## Utilities for managing AMQP frames
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import net

import ./class
import ./errors
import ./types
import ./utils

type AMQPFrameError* = object of AMQPError

proc sendFrame*(conn: AMQPConnection, frame: AMQPFrame): StrWithError =
    ## Sends a pre-formatted AMQP frame to the server
    let stream = newStringStream()

    stream.write(frame.frameType)
    stream.write(frame.channel)

    case frame.payloadType:
    of ptStream:
        let payloadStr = frame.payloadStream.readAll()
        stream.write(uint32(len(payloadStr)))
        stream.write(payloadStr)
    of ptString:
        stream.write(frame.payloadSize)
        stream.write(frame.payloadString)
    
    stream.write(0xCE)

    try:
        conn.sock.send(stream.readAll())
    except OSError as e:
        return (fmt"Failed to send AMQP frame: {e.msg}", true)

    return ("", false)


proc handleFrame*(conn: AMQPConnection) =
    ## Reads an AMQP frame off the wire and checks/parses it.  This is based on the
    ## Advanced Message Queueing Protocol Specification, Section 2.3.5.
    ## `amqpVersion` must be in dotted notation
    var frame = AMQPFrame(payloadType: ptStream)

    # Version negotiation pre-fetches 7B, so we need to account for that
    if conn.stream.atEnd():
        conn.stream.write(conn.sock.recv(7, conn.readTimeout))
        if conn.stream.atEnd():
            raise newException(AMQPFrameError, "Failed to read frame from server")

    frame.frameType = conn.stream.readUint8()
    conn.stream.readNumericEndian(frame.channel)
    conn.stream.readNumericEndian(frame.payloadSize)

    # Frame-end is a single octet that must be set to 0xCE (thus the +1)
    let payload_plus_frame_end = conn.sock.recv(int(frame.payloadSize)+1, conn.readTimeout)
    
    # Ensure the frame-end octet matches the spec
    if byte(payload_plus_frame_end[frame.payloadSize]) != 0xCE:
        raise newException(AMQPFrameError, "Corrupt frame, missing 0xCE ending marker")

    frame.payloadStream = newStringStream(payload_plus_frame_end[0..(frame.payloadSize-1)])

    # TODO: Dispatch this frame based on the frame type
    if frame.frameType == 1:
        classMethodDispatcher(conn, frame)
    else:
        raise newException(AMQPFrameError, fmt"Got unexpected frame type '{frame.frameType}'")


proc readTLSFrame*(): string = 
    ## Reads an AMQP frame from a TLS encrypted session
    raise newException(Exception, "not implemented")