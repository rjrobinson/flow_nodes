# frozen_string_literal: true

RSpec.describe FlowNodes do
  it "has a version number" do
    expect(FlowNodes::VERSION).not_to be_nil
  end

  it "runs a simple linear flow" do
    class TestA < FlowNodes::Node
      def exec(_); "default"; end
    end
    class TestB < FlowNodes::Node
      def exec(_); nil; end
    end

    a = TestA.new
    b = TestB.new
    a >> b
    flow = FlowNodes::Flow.new(start: a)
    expect { flow.run(nil) }.not_to raise_error
  end
end