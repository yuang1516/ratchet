require "ratchet"

counter = 0

function ctx1(where)
    local rec = ratchet.socket.prepare_uri(where)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    kernel:attach(ctx2, "tcp://localhost:10025")

    local client = socket:accept()

    -- Portion being tested.
    --
    local data = client:recv()
    assert(data == "not encrypted")
    client:send("yet")

    local enc = client:encrypt(ssl1)
    enc:server_handshake()

    client:send("hello")
    local data = client:recv()
    assert(data == "world")

    local data = client:recv()
    assert(data == "foo")
    client:send("bar")

    counter = counter + 1
end

function ctx2(where)
    local rec = ratchet.socket.prepare_uri(where)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    -- Portion being tested.
    --
    socket:send("not encrypted")
    local data = socket:recv()
    assert(data == "yet")

    local enc = socket:encrypt(ssl2)
    enc:client_handshake()
    enc:check_certificate_chain(rec.host)

    local data = socket:recv()
    assert(data == "hello")
    socket:send("world")

    socket:send("foo")
    local data = socket:recv()
    assert(data == "bar")

    counter = counter + 2
end

ssl1 = ratchet.ssl.new(ratchet.ssl.SSLv3_server)
ssl1:load_certs("cert.pem")

ssl2 = ratchet.ssl.new(ratchet.ssl.SSLv3_client)
ssl2:load_cas(nil, "cert.pem")

kernel = ratchet.new()
kernel:attach(ctx1, "tcp://localhost:10025")
kernel:loop()

assert(counter == 3)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
