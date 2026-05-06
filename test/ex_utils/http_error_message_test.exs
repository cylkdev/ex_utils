defmodule ExUtils.HTTPErrorMessageTest do
  use ExUnit.Case, async: true

  alias ExUtils.HTTPErrorMessage, as: ErrorHandler

  defmodule FakeErrorMessage do
    @moduledoc false

    for fun <- ~w(
          multiple_choices moved_permanently found see_other not_modified use_proxy
          switch_proxy temporary_redirect permanent_redirect
          bad_request unauthorized payment_required forbidden not_found
          method_not_allowed not_acceptable proxy_authentication_required
          request_timeout conflict gone length_required precondition_failed
          request_entity_too_large request_uri_too_long unsupported_media_type
          requested_range_not_satisfiable expectation_failed im_a_teapot
          misdirected_request unprocessable_entity locked failed_dependency
          too_early upgrade_required precondition_required too_many_requests
          request_header_fields_too_large unavailable_for_legal_reasons
          internal_server_error not_implemented bad_gateway service_unavailable
          gateway_timeout http_version_not_supported variant_also_negotiates
          insufficient_storage loop_detected not_extended
          network_authentication_required
        )a do
      def unquote(fun)(message, details) do
        {:fake, unquote(fun), message, details}
      end
    end
  end

  @recognized_codes [
    {300, :multiple_choices, "multiple choices available for the requested resource"},
    {301, :moved_permanently, "the resource has been permanently moved"},
    {302, :found, "the resource was found at a different location"},
    {303, :see_other, "see other resource for the response"},
    {304, :not_modified, "the resource has not been modified"},
    {305, :use_proxy, "the resource must be accessed through a proxy"},
    {306, :switch_proxy, "the switch proxy status is no longer in use"},
    {307, :temporary_redirect,
     "the request must be repeated against a temporary redirect target"},
    {308, :permanent_redirect,
     "the request must be repeated against the permanent redirect target"},
    {400, :bad_request, "the server cannot process the request due to malformed syntax"},
    {401, :unauthorized, "authentication is required to access this resource"},
    {402, :payment_required, "payment is required before this resource can be accessed"},
    {403, :forbidden, "the server refuses to authorize this request"},
    {404, :not_found, "the requested resource could not be found"},
    {405, :method_not_allowed, "the request method is not allowed for this resource"},
    {406, :not_acceptable, "the resource cannot produce a response acceptable to the client"},
    {407, :proxy_authentication_required,
     "authentication with the proxy is required before the request can proceed"},
    {408, :request_timeout, "the server timed out waiting for the request"},
    {409, :conflict, "the request conflicts with the current state of the resource"},
    {410, :gone, "the resource is no longer available and will not be available again"},
    {411, :length_required, "the request did not specify the required content length"},
    {412, :precondition_failed, "a precondition declared in the request headers failed"},
    {413, :request_entity_too_large,
     "the request payload is larger than the server is willing to process"},
    {414, :request_uri_too_long,
     "the request URI is longer than the server is willing to interpret"},
    {415, :unsupported_media_type,
     "the request payload is in a media type the server does not support"},
    {416, :requested_range_not_satisfiable, "the requested byte range cannot be satisfied"},
    {417, :expectation_failed,
     "the server cannot meet the expectations declared in the Expect header"},
    {418, :im_a_teapot, "the server refuses to brew coffee because it is a teapot"},
    {421, :misdirected_request,
     "the request was directed at a server that cannot produce a response"},
    {422, :unprocessable_entity, "the request is well-formed but could not be processed"},
    {423, :locked, "the resource is locked and cannot be modified"},
    {424, :failed_dependency, "the request failed because a dependent request failed"},
    {425, :too_early, "the server is unwilling to risk processing a replayed request"},
    {426, :upgrade_required, "the client must upgrade to a different protocol"},
    {428, :precondition_required,
     "the request must be conditional but no precondition was supplied"},
    {429, :too_many_requests, "the client has sent too many requests in the allowed time window"},
    {431, :request_header_fields_too_large,
     "the request headers are too large for the server to process"},
    {451, :unavailable_for_legal_reasons, "the resource is unavailable for legal reasons"},
    {500, :internal_server_error, "the server encountered an unexpected condition"},
    {501, :not_implemented, "the server does not support the functionality required"},
    {502, :bad_gateway, "the server received an invalid response from an upstream server"},
    {503, :service_unavailable, "the server is temporarily unable to handle the request"},
    {504, :gateway_timeout, "an upstream server failed to respond in time"},
    {505, :http_version_not_supported, "the server does not support the requested HTTP version"},
    {506, :variant_also_negotiates, "content negotiation produced a circular reference"},
    {507, :insufficient_storage, "the server has insufficient storage to complete the request"},
    {508, :loop_detected, "the server detected an infinite loop while processing the request"},
    {510, :not_extended, "further extensions to the request are required to fulfill it"},
    {511, :network_authentication_required, "the client must authenticate to gain network access"}
  ]

  describe "status_code_to_message/1 — recognized codes" do
    for {code, _atom, message} <- @recognized_codes do
      test "returns the default message for #{code}" do
        assert ErrorHandler.status_code_to_message(unquote(code)) === unquote(message)
      end
    end
  end

  describe "status_code_to_message/1 — bucket fallbacks" do
    test "unrecognized 3xx returns the redirect bucket message" do
      assert ErrorHandler.status_code_to_message(309) === "redirect not followed"
    end

    test "unrecognized 4xx returns the client error bucket message" do
      assert ErrorHandler.status_code_to_message(499) === "client error"
    end

    test "unrecognized 5xx returns the internal server error bucket message" do
      assert ErrorHandler.status_code_to_message(599) === "internal server error"
    end
  end

  describe "status_code_to_message/1 — option independence" do
    test "ignores :status_code_messages even if it would be passed" do
      # status_code_to_message/1 is arity 1; the override may only flow through
      # status_code_to_error_message/3. This test asserts the documented arity contract.
      assert function_exported?(ErrorHandler, :status_code_to_message, 1)
      refute function_exported?(ErrorHandler, :status_code_to_message, 2)
    end
  end

  describe "status_code_to_error_message/3 — recognized codes" do
    for {code, atom, message} <- @recognized_codes do
      test "code #{code} returns ErrorMessage with code :#{atom} and the default message" do
        details = %{request_id: "abc-#{unquote(code)}"}

        assert %ErrorMessage{
                 code: unquote(atom),
                 message: unquote(message),
                 details: ^details
               } = ErrorHandler.status_code_to_error_message(unquote(code), details, [])
      end
    end
  end

  describe "status_code_to_error_message/3 — unrecognized codes" do
    test "309 maps to :bad_request with the 3xx bucket message" do
      details = %{x: 1}

      assert %ErrorMessage{
               code: :bad_request,
               message: "redirect not followed",
               details: ^details
             } =
               ErrorHandler.status_code_to_error_message(309, details, [])
    end

    test "499 maps to :not_found with the 4xx bucket message" do
      details = %{x: 2}

      assert %ErrorMessage{code: :not_found, message: "client error", details: ^details} =
               ErrorHandler.status_code_to_error_message(499, details, [])
    end

    test "599 maps to :internal_server_error with the 5xx bucket message" do
      details = %{x: 3}

      assert %ErrorMessage{
               code: :internal_server_error,
               message: "internal server error",
               details: ^details
             } = ErrorHandler.status_code_to_error_message(599, details, [])
    end
  end

  describe "status_code_to_error_message/3 — 2xx raises" do
    for code <- [200, 201, 204, 226, 299] do
      test "code #{code} raises a RuntimeError" do
        assert_raise RuntimeError, ~r/#{unquote(code)}/, fn ->
          ErrorHandler.status_code_to_error_message(unquote(code), %{}, [])
        end
      end
    end
  end

  describe "status_code_to_error_message/3 — :status_code_messages override" do
    test "applies the override to the listed code and falls back for the unlisted code" do
      opts = [status_code_messages: [{401, "custom unauthorized"}]]

      assert %ErrorMessage{code: :unauthorized, message: "custom unauthorized"} =
               ErrorHandler.status_code_to_error_message(401, %{}, opts)

      assert %ErrorMessage{
               code: :not_found,
               message: "the requested resource could not be found"
             } = ErrorHandler.status_code_to_error_message(404, %{}, opts)
    end

    test "applies the override to a bucket-fallback code" do
      opts = [status_code_messages: [{499, "tenant blocked"}]]

      assert %ErrorMessage{code: :not_found, message: "tenant blocked"} =
               ErrorHandler.status_code_to_error_message(499, %{}, opts)
    end

    test "accepts :status_code_messages as a map of code => message" do
      opts = [status_code_messages: %{401 => "map override"}]

      assert %ErrorMessage{code: :unauthorized, message: "map override"} =
               ErrorHandler.status_code_to_error_message(401, %{}, opts)
    end

    test "map :status_code_messages without an entry for the code falls back to default" do
      opts = [status_code_messages: %{500 => "different"}]

      assert %ErrorMessage{
               code: :not_found,
               message: "the requested resource could not be found"
             } = ErrorHandler.status_code_to_error_message(404, %{}, opts)
    end
  end

  describe "status_code_to_error_message/3 — :error_message_module swap" do
    test "uses the supplied module instead of ErrorMessage" do
      opts = [error_message_module: FakeErrorMessage]
      details = %{tenant: "acme"}

      assert {:fake, :unauthorized, "authentication is required to access this resource",
              ^details} =
               ErrorHandler.status_code_to_error_message(401, details, opts)
    end

    test "swap is honored for bucket fallbacks too" do
      opts = [error_message_module: FakeErrorMessage]

      assert {:fake, :internal_server_error, "internal server error", :ignored} =
               ErrorHandler.status_code_to_error_message(599, :ignored, opts)
    end
  end
end
