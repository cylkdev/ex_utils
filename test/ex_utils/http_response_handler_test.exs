defmodule ExUtils.HTTPResponseHandlerTest do
  use ExUnit.Case, async: true

  alias ExUtils.HTTPResponseHandler

  describe "handle_response/3 — {:ok, response}" do
    test "passes through {:ok, _} returned by the function" do
      assert {:ok, :transformed} =
               HTTPResponseHandler.handle_response(
                 {:ok, :raw},
                 fn :raw -> {:ok, :transformed} end,
                 []
               )
    end

    test "passes through {:error, _} returned by the function" do
      assert {:error, :reason} =
               HTTPResponseHandler.handle_response(
                 {:ok, :raw},
                 fn :raw -> {:error, :reason} end,
                 []
               )
    end

    test "wraps a bare term returned by the function in {:ok, term}" do
      assert {:ok, %{hello: "world"}} =
               HTTPResponseHandler.handle_response(
                 {:ok, :raw},
                 fn :raw -> %{hello: "world"} end,
                 []
               )
    end
  end

  describe "handle_response/3 — {:error, {:http_error, status, response}}" do
    test "returns {:error, %ErrorMessage{}} with the default code-derived message" do
      assert {:error, %ErrorMessage{code: :not_found, message: msg, details: %{response: :body}}} =
               HTTPResponseHandler.handle_response(
                 {:error, {:http_error, 404, :body}},
                 fn _ -> :unused end,
                 []
               )

      assert msg === "the requested resource could not be found"
    end

    test "honors :http_error[:message] override when supplied" do
      assert {:error,
              %ErrorMessage{
                code: :unauthorized,
                message: "custom msg",
                details: %{response: :body}
              }} =
               HTTPResponseHandler.handle_response(
                 {:error, {:http_error, 401, :body}},
                 fn _ -> :unused end,
                 http_error: [message: "custom msg"]
               )
    end

    test "falls back to the default message when :http_error is omitted" do
      assert {:error, %ErrorMessage{code: :unauthorized, message: msg}} =
               HTTPResponseHandler.handle_response(
                 {:error, {:http_error, 401, :body}},
                 fn _ -> :unused end,
                 []
               )

      assert msg === "authentication is required to access this resource"
    end

    test "5xx codes produce :internal_server_error with the response in details" do
      assert {:error,
              %ErrorMessage{
                code: :internal_server_error,
                details: %{response: %{trace: "x"}}
              }} =
               HTTPResponseHandler.handle_response(
                 {:error, {:http_error, 500, %{trace: "x"}}},
                 fn _ -> :unused end,
                 []
               )
    end
  end
end
