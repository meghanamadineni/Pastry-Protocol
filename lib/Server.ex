defmodule Pastry.Main do
  
    use GenServer
  
    def handle_cast(:print_state, state) do
      print(state["node_list"], length(state["node_list"])-1) 
      {:noreply, state}
    end
  
    def print(_node_list, -1), do: {}
    def print(node_list, index) do
      GenServer.cast(Enum.at(node_list, index), :print_status)
      print(node_list, index-1)
    end
  
    def handle_call(:start_music, _from, state) do
     
      spawn_nodes(state["num_nodes"], [])
     
      {:reply, :ok, state}
    end
  
    def handle_call(:send_messages_cast, _from, state) do
      node_list = state["node_list"]
      node = Enum.random(node_list)
      hops = hop_count1(node, state["num_requests"], 0)
      IO.inspect "Average number of hops"
      IO.inspect hops/state["num_requests"]# Do not comment
      {:reply, :ok, state}
    end
  
    def hop_count1(node, 0, sum), do: sum
    def hop_count1(node, num_requests, sum) do
     
      hops = GenServer.call(node, :answer_me)
      hop_count1(node, num_requests-1, sum + hops)
    end
  
    def handle_cast({:state_update, node_id}, state) do
      node_list = state["node_list"]
      node_list = [node_id | node_list]
      state = Map.put(state, "node_list", node_list)
      {:noreply, state}  
    end
  
    def handle_cast({:done, avg_hops}, state) do
      count = state["count"] + 1
      avg_hops = state["avg_hops"] + avg_hops
      num_nodes = state["num_nodes"]
    
    
      if count == num_nodes do
       
        Process.exit(self(), :normal)
      end
      {:noreply, make_map({state, avg_hops, count})} 
    end
    
    def make_map({state, avg_hops, count}) do
      %{
        "num_nodes" => state["num_nodes"], 
        "num_requests" => state["num_requests"],
        "node_list" => state["node_list"],
        "avg_hops" => avg_hops,
        "count" => count
      }
    end
  
    def send_messages(_, -1, _), do: [] 
    def send_messages(node_list, index, num_requests) do
      GenServer.cast(Enum.at(node_list, index), {:send_messages, num_requests}) 
      send_messages(node_list, index-1, num_requests)  
    end
  
    def rand_bin_string_128 do
      :binary.bin_to_list(:crypto.strong_rand_bytes(64)) |> Enum.map(fn(x) -> rem(x,2) end)|> Enum.join
    end
  
    def spawn_nodes(1, []) do
      
      node_id = String.to_atom(rand_bin_string_128())
     
      state = %{"node_id"=> node_id, "start_id"=> nil, "leaf_set"=> [node_id], "routing_table"=> %{}}
      GenServer.start_link(Pastry.Node, state, name: node_id) 
      GenServer.cast(:main, {:state_update, node_id})
     
    end
  
    def spawn_nodes(1, node_list) do
     
      random_node_id = Enum.random(node_list)
      node_id = String.to_atom(rand_bin_string_128())
     
      state = %{"node_id"=> node_id, "start_id"=> random_node_id, "leaf_set"=> [node_id], "routing_table"=> %{}}
      GenServer.start_link(Pastry.Node, state, name: node_id) 
      GenServer.call(node_id, :start_dance)
      GenServer.cast(:main, {:state_update, node_id})
     
    end
  
    def spawn_nodes(n, []) do
     
      node_id = String.to_atom(rand_bin_string_128())
     
      state = %{"node_id"=> node_id, "start_id"=> nil, "leaf_set"=> [node_id], "routing_table"=> %{}}
      GenServer.start_link(Pastry.Node, state, name: node_id)
      GenServer.call(node_id, :start_dance)
      GenServer.cast(:main, {:state_update, node_id})
      spawn_nodes(n-1, [node_id])
      
    end
  
    def spawn_nodes(n, node_list) do

      random_node_id = Enum.random(node_list)
      node_id = String.to_atom(rand_bin_string_128())
      
      state = %{
        "node_id" => node_id, 
        "start_id" => random_node_id, 
        "leaf_set" => [node_id], 
        "routing_table" => %{}
      }
      GenServer.start_link(Pastry.Node, state, name: node_id)
      GenServer.call(node_id, :start_dance)
      GenServer.cast(:main, {:state_update, node_id})
      spawn_nodes(n-1, [node_id|node_list])
     
    end
  end
  