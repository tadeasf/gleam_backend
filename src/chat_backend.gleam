import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option.{Some}
import mist.{type Connection, type ResponseData}
import routes/messaging

// Entry point of the application
pub fn main() {
  io.println("Starting the server...")

  // These values are for the WebSocket process initialized below
  let selector = process.new_selector()
  let state = Nil

  // Define a not-found response
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))

  // Set up HTTP routes and start the server
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(state, Some(selector)) },
            on_close: fn(_state) { io.println("goodbye!") },
            handler: messaging.handle_ws_message,
          )
        ["echo"] -> messaging.echo_body(req)
        ["chunk"] -> messaging.serve_chunk(req)
        ["file", ..rest] -> messaging.serve_file(req, rest)
        ["form"] -> messaging.handle_form(req)
        _ -> not_found
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

