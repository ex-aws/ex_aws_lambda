defmodule ExAws.LambdaTest do
  use ExUnit.Case, async: true

  test "#list_functions" do
    assert %ExAws.Operation.JSON{
      before_request: nil,
      data: %{},
      headers: [{"content-type", "application/json"}],
      http_method: :get,
      params: %{},
      parser: _,
      path: "/2015-03-31/functions/?",
      service: :lambda,
      stream_builder: nil
    } = ExAws.Lambda.list_functions
  end

  describe "Lambda.invoke" do
    test "callback on invoke works for encoding context before request" do
      op = ExAws.Lambda.invoke("func-name", "func-payload", "asdfasdf")
      before_request = op.before_request.(op, %{json_codec: Poison})

      assert {"X-Amz-Client-Context", "ImFzZGZhc2RmIg=="} in before_request.headers
    end

    test "xray_trace_id option adds the X-Amzn-Trace-Id header" do
      op = ExAws.Lambda.invoke("func-name", "func-payload", %{}, xray_trace_id: "1-aaaaa-bbbbbbbbb")
      assert {"X-Amzn-Trace-Id", "1-aaaaa-bbbbbbbbb"} in op.headers
    end

    test "builds ExAws operation" do
      assert %ExAws.Operation.JSON{
        before_request: _,
        data: "func-payload",
        headers: [
          {"content-type", "application/json"}
        ],
        http_method: :post,
        params: %{},
        parser: _,
        path: "/2015-03-31/functions/func-name/invocations?",
        service: :lambda,
        stream_builder: nil
      } = ExAws.Lambda.invoke("func-name", "func-payload", %{})
    end
  end
end
