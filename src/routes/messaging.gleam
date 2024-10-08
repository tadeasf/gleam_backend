import gleam/bytes_builder
import gleam/io
import gleam/otp/actor
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/iterator
import gleam/result
import gleam/string
import gleam/option.{None}
import mist.{type Connection, type ResponseData}

// Define Broadcast type
pub type MyMessage {
  Broadcast(String)
}

// WebSocket message handler
pub fn handle_ws_message(state, conn, message) {
  case message {
    mist.Text("ping") -> {
      io.println("Responding with pong")
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    mist.Custom(Broadcast(text)) -> {
      io.println("Broadcasting message")
      let assert Ok(_) = mist.send_text_frame(conn, text)
      actor.continue(state)
    }
    mist.Text(_) -> {
      actor.continue(state)
    }
    mist.Binary(_) -> {
      actor.continue(state)
    }
    mist.Closed | mist.Shutdown -> {
      io.println("WebSocket closed or shutdown")
      actor.Stop(process.Normal)
    }
  }
}

// HTTP request handlers
pub fn echo_body(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  mist.read_body(request, 1024 * 1024 * 10)
  |> result.map(fn(req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_bit_array(req.body)))
    |> response.set_header("content-type", content_type)
  })
  |> result.lazy_unwrap(fn() {
    response.new(400)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}

pub fn serve_chunk(_request: Request(Connection)) -> Response(ResponseData) {
  let iter =
    ["one", "two", "three"]
    |> iterator.from_list
    |> iterator.map(bytes_builder.from_string)

  response.new(200)
  |> response.set_body(mist.Chunked(iter))
  |> response.set_header("content-type", "text/plain")
}

pub fn serve_file(
  _req: Request(Connection),
  path: List(String),
) -> Response(ResponseData) {
  let file_path = string.join(path, "/")

  // Omitting validation for brevity
  mist.send_file(file_path, offset: 0, limit: None)
  |> result.map(fn(file) {
    let content_type = guess_content_type(file_path)
    response.new(200)
    |> response.prepend_header("content-type", content_type)
    |> response.set_body(file)
  })
  |> result.lazy_unwrap(fn() {
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}

pub fn handle_form(req: Request(Connection)) -> Response(ResponseData) {
  mist.read_body(req, 1024 * 1024 * 30)
  |> result.map(fn(req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_bit_array(req.body)))
  })
  |> result.lazy_unwrap(fn() {
    response.new(400)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}


fn guess_content_type(_path: String) -> String {
  "application/octet-stream"
}

