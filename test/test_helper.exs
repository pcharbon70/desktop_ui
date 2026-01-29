# Import the integration test helper before starting ExUnit
# This ensures the helper module is compiled before integration tests use it
Code.require_file("integration/test_helper.ex", __DIR__)

# Import the NIF test helper module
Code.require_file("desktop_ui/nif/test_helper.exs", __DIR__)

ExUnit.start()
