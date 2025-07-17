# frozen_string_literal: true
# rubocop:disable all
require_relative "flow_nodes/version"
module FlowNodes
  class BaseNode
    attr_accessor :params,:successors
    def initialize;@params={};@successors={};end
    def set_params(p);@params=p||{};end
    def nxt(n,act="default");warn("Overwriting successor for action '#{act}'") if @successors.key?(act);@successors[act]=n;n;end;alias next nxt
    def prep(s);nil;end;def exec(p);nil;end;def post(s,p,e);nil;end
    def _exec(p);exec(p);end
    def _run(s);pr=prep(s);er=_exec(pr);post(s,pr,er);end
    def run(s);warn("Node won't run successors. Use Flow.") unless @successors.empty?;_run(s);end
    def >>(o);nxt(o);end
    def -(a);raise TypeError,"Action must be String/Symbol" unless a.is_a?(String)||a.is_a?(Symbol);ConditionalTransition.new(self,a.to_s);end
  end

  class ConditionalTransition
    def initialize(src,a);@src,@a=src,a;end
    def >>(t);@src.nxt(t,@a);end
  end

  class Node < BaseNode
    attr_reader :max_retries,:wait,:cur_retry
    def initialize(max_retries:1,wait:0);super();@max_retries=max_retries;@wait=wait;@cur_retry=0;end
    def exec_fallback(p,exc);raise exc;end
    def _exec(p);last=nil;@max_retries.times do |i|;@cur_retry=i;begin;return exec(p);rescue=>e;last=e;if i==@max_retries-1;return exec_fallback(p,e);else;sleep @wait if @wait.to_f>0;end;end;end;raise last if last;end
  end

  class BatchNode < Node
    def _exec(items);Array(items).map{|i|super(i)};end
  end

  class Flow < BaseNode
    attr_accessor :start_node
    def initialize(start:nil);super();@start_node=start;end
    def start(n);@start_node=n;n;end
    def get_next_node(c,a);k=(a.nil?||a=="")?"default":a;n=c.successors[k];warn("Flow ends: '#{k}' not found in #{c.successors.keys.inspect}") if !n&&!c.successors.empty?;n;end
    def _orch(s,params:nil);raise "Flow has no start node" unless @start_node;c=@start_node.dup;p=params ? params.dup : @params.dup;last=nil;while c; c.set_params(p); last=c._run(s); c=get_next_node(c,last)&.dup; end; last;end
    def _run(s);pr=prep(s);o=_orch(s);post(s,pr,o);end
    def post(s,pr,er);er;end
  end

  class BatchFlow < Flow
    def _run(s);pr=prep(s)||[];pr.each{|bp|_orch(s,params:@params.merge(bp))};post(s,pr,nil);end
  end

  class AsyncNode < Node
    def prep_async(s);nil;end;def exec_async(p);nil;end
    def exec_fallback_async(p,exc);raise exc;end
    def post_async(s,p,e);nil;end
    def _exec_async(p);last=nil;@max_retries.times do |i|;begin;return exec_async(p);rescue=>e;last=e;if i==@max_retries-1;return exec_fallback_async(p,e);else;sleep @wait if @wait.to_f>0;end;end;end;raise last if last;end
    def run_async(s);warn("Node won't run successors. Use AsyncFlow.") unless @successors.empty?;_run_async(s);end
    def _run_async(s);pr=prep_async(s);er=_exec_async(pr);post_async(s,pr,er);end
    def _run(_);raise "Use run_async.";end
  end

  class AsyncBatchNode < AsyncNode
    def _exec_async(items);Array(items).map{|i|super(i)};end
  end

  class AsyncParallelBatchNode < AsyncNode
    def _exec_async(items);threads=Array(items).map{|i|Thread.new{super(i)}};threads.map(&:value);end
  end

  class AsyncFlow < Flow
    def _orch_async(s,params:nil);raise "Flow has no start node" unless @start_node;c=@start_node.dup;p=params ? params.dup : @params.dup;last=nil;while c; c.set_params(p); last=(c.is_a?(AsyncNode)?c._run_async(s):c._run(s)); c=get_next_node(c,last)&.dup; end; last;end
    def _run_async(s);pr=prep_async(s);o=_orch_async(s);post_async(s,pr,o);end
    def post_async(s,pr,er);er;end
    def _run(_);raise "Use run_async.";end
  end

  class AsyncBatchFlow < AsyncFlow
    def _run_async(s);pr=prep_async(s)||[];pr.each{|bp|_orch_async(s,params:@params.merge(bp))};post_async(s,pr,nil);end
  end

  class AsyncParallelBatchFlow < AsyncFlow
    def _run_async(s);pr=prep_async(s)||[];ths=pr.map{|bp|Thread.new{_orch_async(s,params:@params.merge(bp))}};ths.map(&:value);post_async(s,pr,nil);end
  end
end
# rubocop:enable all
