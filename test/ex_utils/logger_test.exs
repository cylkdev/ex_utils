defmodule ExUtils.LoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias ExUtils.Logger, as: Subject

  setup do
    prior_level = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: prior_level) end)
    :ok
  end

  describe "default formatter" do
    test "debug/4 emits [prefix] message" do
      log = capture_log(fn -> Subject.debug("App", "hello") end)
      assert log =~ "[App] hello"
    end

    test "info/4 emits [prefix] message" do
      log = capture_log(fn -> Subject.info("App", "hello") end)
      assert log =~ "[App] hello"
    end

    test "warning/4 emits [prefix] message" do
      log = capture_log(fn -> Subject.warning("App", "careful") end)
      assert log =~ "[App] careful"
    end

    test "error/4 emits [prefix] message" do
      log = capture_log(fn -> Subject.error("App", "boom") end)
      assert log =~ "[App] boom"
    end
  end

  describe "custom :format_message" do
    test "honored when arity-2" do
      formatter = fn prefix, msg -> "<#{prefix}>::<#{msg}>" end

      log =
        capture_log(fn ->
          Subject.info("App", "ping", [], format_message: formatter)
        end)

      assert log =~ "<App>::<ping>"
    end

    test "raises ArgumentError when wrong arity" do
      bad = fn -> "wrong" end

      assert_raise ArgumentError, ~r/format_message function must accept 2 arguments/, fn ->
        Subject.info("App", "ping", [], format_message: bad)
      end
    end
  end

  describe "metadata is forwarded to Logger" do
    test "debug/4 forwards metadata keyword list" do
      log =
        capture_log(fn ->
          Subject.debug("App", "hello", request_id: "abc")
        end)

      assert log =~ "[App] hello"
    end
  end
end
