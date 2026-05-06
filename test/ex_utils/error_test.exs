defmodule ExUtils.ErrorTest do
  use ExUnit.Case, async: true

  alias ExUtils.Error

  defmodule FakeNamed do
    @moduledoc false

    def not_found(message, details), do: {:named, :not_found, message, details}
    def unauthorized(message, details), do: {:named, :unauthorized, message, details}

    def internal_server_error(message, details),
      do: {:named, :internal_server_error, message, details}
  end

  defmodule FakeCall do
    @moduledoc false

    def call(name, message, details), do: {:call, name, message, details}
  end

  defmodule FakeNeither do
    @moduledoc false
  end

  @all_names ~w(
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
  )a

  describe "default error-message module path" do
    test "not_found/3 returns an %ErrorMessage{} via the default ErrorMessage module" do
      details = %{id: 1}

      assert %ErrorMessage{code: :not_found, message: "missing", details: ^details} =
               Error.not_found("missing", details, [])
    end

    test "unauthorized/3 returns an %ErrorMessage{} via the default ErrorMessage module" do
      details = %{tenant: "acme"}

      assert %ErrorMessage{code: :unauthorized, message: "auth required", details: ^details} =
               Error.unauthorized("auth required", details, [])
    end

    test "internal_server_error/3 returns an %ErrorMessage{} via the default ErrorMessage module" do
      details = %{request_id: "abc"}

      assert %ErrorMessage{
               code: :internal_server_error,
               message: "boom",
               details: ^details
             } = Error.internal_server_error("boom", details, [])
    end
  end

  describe "custom :error_message_module exporting <name>/2" do
    test "not_found/3 calls FakeNamed.not_found/2 directly" do
      assert {:named, :not_found, "missing", %{id: 1}} =
               Error.not_found("missing", %{id: 1}, error_message_module: FakeNamed)
    end

    test "unauthorized/3 calls FakeNamed.unauthorized/2 directly" do
      assert {:named, :unauthorized, "auth required", %{tenant: "acme"}} =
               Error.unauthorized("auth required", %{tenant: "acme"},
                 error_message_module: FakeNamed
               )
    end

    test "internal_server_error/3 calls FakeNamed.internal_server_error/2 directly" do
      assert {:named, :internal_server_error, "boom", %{request_id: "abc"}} =
               Error.internal_server_error("boom", %{request_id: "abc"},
                 error_message_module: FakeNamed
               )
    end
  end

  describe "custom :error_message_module exporting only call/3" do
    test "not_found/3 invokes call(:not_found, message, details)" do
      assert {:call, :not_found, "missing", %{id: 1}} =
               Error.not_found("missing", %{id: 1}, error_message_module: FakeCall)
    end

    test "unauthorized/3 invokes call(:unauthorized, message, details)" do
      assert {:call, :unauthorized, "auth required", %{tenant: "acme"}} =
               Error.unauthorized("auth required", %{tenant: "acme"},
                 error_message_module: FakeCall
               )
    end

    test "internal_server_error/3 invokes call(:internal_server_error, message, details)" do
      assert {:call, :internal_server_error, "boom", %{request_id: "abc"}} =
               Error.internal_server_error("boom", %{request_id: "abc"},
                 error_message_module: FakeCall
               )
    end
  end

  describe "custom :error_message_module exporting neither" do
    test "not_found/3 raises a RuntimeError naming the module" do
      assert_raise RuntimeError, ~r/FakeNeither/, fn ->
        Error.not_found("missing", %{}, error_message_module: FakeNeither)
      end
    end

    test "unauthorized/3 raises a RuntimeError naming the module" do
      assert_raise RuntimeError, ~r/FakeNeither/, fn ->
        Error.unauthorized("auth required", %{}, error_message_module: FakeNeither)
      end
    end

    test "internal_server_error/3 raises a RuntimeError naming the module" do
      assert_raise RuntimeError, ~r/FakeNeither/, fn ->
        Error.internal_server_error("boom", %{}, error_message_module: FakeNeither)
      end
    end
  end

  describe "every public name dispatches to ErrorMessage.<name>/2" do
    for name <- @all_names do
      test "#{name}/3 returns %ErrorMessage{code: :#{name}, ...}" do
        assert %ErrorMessage{code: unquote(name), message: "msg", details: %{a: 1}} =
                 apply(Error, unquote(name), ["msg", %{a: 1}, []])
      end
    end
  end

  describe "every public name falls back to call/3 when only call/3 is exported" do
    for name <- @all_names do
      test "#{name}/3 invokes FakeCall.call(:#{name}, message, details)" do
        assert {:call, unquote(name), "msg", %{a: 1}} =
                 apply(Error, unquote(name), ["msg", %{a: 1}, [error_message_module: FakeCall]])
      end
    end
  end

  describe "every public name raises when neither <name>/2 nor call/3 is exported" do
    for name <- @all_names do
      test "#{name}/3 raises a RuntimeError naming FakeNeither" do
        assert_raise RuntimeError, ~r/FakeNeither/, fn ->
          apply(Error, unquote(name), [
            "msg",
            %{a: 1},
            [error_message_module: FakeNeither]
          ])
        end
      end
    end
  end
end
