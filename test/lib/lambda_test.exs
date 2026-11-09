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
           } = ExAws.Lambda.list_functions()
  end

  describe "Lambda.invoke" do
    test "callback on invoke works for encoding context before request" do
      op = ExAws.Lambda.invoke("func-name", "func-payload", "asdfasdf")
      before_request = op.before_request.(op, %{json_codec: Poison})

      assert {"X-Amz-Client-Context", "ImFzZGZhc2RmIg=="} in before_request.headers
    end

    test "xray_trace_id option adds the X-Amzn-Trace-Id header" do
      op =
        ExAws.Lambda.invoke("func-name", "func-payload", %{}, xray_trace_id: "1-aaaaa-bbbbbbbbb")

      assert {"X-Amzn-Trace-Id", "1-aaaaa-bbbbbbbbb"} in op.headers
    end

    test "builds ExAws JSON operation" do
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

    test "builds ExAws RestQuery operation" do
      assert %ExAws.Operation.RestQuery{
               body: "func-payload",
               http_method: :post,
               params: %{},
               parser: parser_func,
               path: "/2015-03-31/functions/func-name/invocations?",
               service: :lambda
             } = ExAws.Lambda.invoke("func-name", "func-payload", %{}, parser: &{&1, &2})

      assert is_function(parser_func, 2)
    end
  end

  describe "identifier encoding (GHSA-rxg9-76jv-f68p)" do
    test "plain identifiers are passed through unchanged" do
      assert ExAws.Lambda.delete_function("my-fn").path == "/2015-03-31/functions/my-fn?"

      assert ExAws.Lambda.remove_permission("my-fn", "sid-1").path ==
               "/2015-03-31/functions/my-fn/versions/HEAD/policy/sid-1?"
    end

    test "path separators and dot segments in a function name stay inside one segment" do
      assert ExAws.Lambda.delete_function("tenant-a-fn/../victim-fn").path ==
               "/2015-03-31/functions/tenant-a-fn%2F..%2Fvictim-fn?"
    end

    test "query and fragment metacharacters cannot alter the request" do
      assert ExAws.Lambda.delete_function("my-fn?Qualifier=5").path ==
               "/2015-03-31/functions/my-fn%3FQualifier%3D5?"

      assert ExAws.Lambda.remove_permission("my-fn#", "sid").path ==
               "/2015-03-31/functions/my-fn%23/versions/HEAD/policy/sid?"

      assert ExAws.Lambda.remove_permission("my-fn", "sid?Qualifier=prod").path ==
               "/2015-03-31/functions/my-fn/versions/HEAD/policy/sid%3FQualifier%3Dprod?"
    end

    test "qualified names and ARNs are encoded like the AWS SDKs do" do
      assert ExAws.Lambda.invoke("my-fn:prod", %{}, %{}).path ==
               "/2015-03-31/functions/my-fn%3Aprod/invocations?"

      assert ExAws.Lambda.tag_resource("arn:aws:lambda:us-east-1:123456789012:function:my-fn", %{
               a: "b"
             }).path ==
               "/2017-03-31/tags/arn%3Aaws%3Alambda%3Aus-east-1%3A123456789012%3Afunction%3Amy-fn?"
    end

    test "every operation taking an identifier encodes it" do
      bad = "a/../b?x=1#y"
      enc = "a%2F..%2Fb%3Fx%3D1%23y"

      paths = [
        ExAws.Lambda.add_permission(bad, "p", "lambda:InvokeFunction", bad).path,
        ExAws.Lambda.delete_event_source_mapping(bad).path,
        ExAws.Lambda.delete_function(bad).path,
        ExAws.Lambda.get_event_source_mapping(bad).path,
        ExAws.Lambda.get_function(bad).path,
        ExAws.Lambda.get_function_configuration(bad).path,
        ExAws.Lambda.get_policy(bad).path,
        ExAws.Lambda.invoke(bad, %{}, %{}).path,
        ExAws.Lambda.invoke_async(bad, %{}).path,
        ExAws.Lambda.remove_permission(bad, bad).path,
        ExAws.Lambda.update_event_source_mapping(bad, %{}).path,
        ExAws.Lambda.update_function_code(bad, "zip").path,
        ExAws.Lambda.update_function_configuration(bad, %{}).path,
        ExAws.Lambda.tag_resource(bad, %{}).path
      ]

      for path <- paths do
        refute path =~ bad
        assert path =~ enc
        # exactly one "?" remains: the separator request/6 appends for params
        assert length(String.split(path, "?")) == 2
      end
    end

    test "invoke qualifier is sent as an encoded query parameter" do
      assert ExAws.Lambda.invoke("my-fn", %{}, %{}, qualifier: "prod").path ==
               "/2015-03-31/functions/my-fn/invocations?Qualifier=prod"

      assert ExAws.Lambda.invoke("my-fn", %{}, %{}, qualifier: "prod&LogType=Tail").path ==
               "/2015-03-31/functions/my-fn/invocations?Qualifier=prod%26LogType%3DTail"
    end
  end
end
