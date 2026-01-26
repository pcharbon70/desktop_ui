# Import the integration test helper before starting ExUnit
# This ensures the helper module is compiled before integration tests use it
Code.require_file("integration/test_helper.ex", __DIR__)

ExUnit.start()
