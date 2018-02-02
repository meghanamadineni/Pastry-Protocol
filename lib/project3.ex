defmodule Pastry do
  def main(args) do
    [num_nodes, num_requests] = args
    state = %{
      "num_nodes" => elem(Integer.parse(num_nodes), 0), 
      "num_requests" => elem(Integer.parse(num_requests), 0),
      "node_list" => [],
      "avg_hops" => 0,
      "count"=> 0
    }
   
    GenServer.start_link(Pastry.Main, state, name: :main)
    GenServer.call(:main, :start_music, :infinity)
    GenServer.call(:main, :send_messages_cast, :infinity)
    
  end

  def call_itself() do
    call_itself()
  end
end




