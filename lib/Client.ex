defmodule Pastry.Node do
    @leafs 4
    use GenServer
  
    def handle_call(:answer_me, _from, state) do
      key = Pastry.Main.rand_bin_string_128()
      n = lcp([String.to_atom(key), state["node_id"]])
      routing_table = state["routing_table"]
      next_hop_id = Map.get(routing_table, n)
      hop_count = send_message_hop(key, next_hop_id, 1)
      {:reply, hop_count, state}
    end
  
    def send_message_hop(key, nil, hop_count), do: hop_count
    def send_message_hop(key, next_hop_id, hop_count) do
    
      next_hop_id = GenServer.call(next_hop_id, {:hop_count, key})
      send_message_hop(key, next_hop_id, hop_count+1)  
    end
  
    def handle_call({:hop_count, key}, _from, state) do
    
      node_id = state["node_id"]
      n = lcp([node_id, String.to_atom(key)])
      routing_table = state["routing_table"]
      
      {:reply, Map.get(routing_table, n), state}
    end
  
    def handle_cast(:print_state, state) do
     
      {:noreply, state}
    end
  
    def handle_cast({:send_messages, num_requests}, state) do
      
      sum = get_hop_count(state, num_requests, 0)
     
      GenServer.cast(:main, {:done, sum/num_requests})
      {:noreply, state}
    end
  
    def get_hop_count(state, 0, sum), do: sum
    def get_hop_count(state, num_requests, sum) do
     
      key = Pastry.Main.rand_bin_string_128()
      node_id = state["node_id"]
      hop_count = 1
      n = lcp([String.to_atom(key), node_id])
      routing_table = state["routing_table"]
      next_hop_id = Map.get(routing_table, n)
  
      hops = send_message_hop(key, next_hop_id, hop_count)
      get_hop_count(state, num_requests-1, sum+hops)
    end
  
    def handle_call(:start_dance, _from, state) do
      
      {routing_table, closest_node} = update_routing_table(state["node_id"], state["start_id"], %{})
     
      if closest_node == nil do
        {:reply, :ok, state}  
      else
      
      leaf_set = GenServer.call(closest_node, :get_children)
     
      if length(leaf_set) < @leafs do
        
        Enum.each(leaf_set, fn(leaf) -> 
          GenServer.call(leaf, {:update_leaf_set_and_routing, [state["node_id"] | leaf_set], nil})
        end)
        state = Map.put(state, "leaf_set", [state["node_id"] | leaf_set])  
      else
        
        leaf_set = [state["node_id"] | leaf_set]
        {list_0, list_1, n} = split(leaf_set, length(leaf_set)-1, [], [])
       
        Enum.each(list_0, fn(leaf) ->
          unless leaf == state["node_id"] do 
           
            GenServer.call(leaf, {:update_leaf_set_and_routing, list_0, {n, Enum.random(list_1)}})
          end  
        end)
        Enum.each(list_1, fn(leaf) -> 
          unless leaf == state["node_id"] do 
            
            GenServer.call(leaf, {:update_leaf_set_and_routing, list_1, {n, Enum.random(list_0)}}) 
          end 
        end)
  
        if Enum.member?(list_0, state["node_id"]) do
          routing_table = Map.put(routing_table, n, Enum.random(list_1))
        else
          routing_table = Map.put(routing_table, n, Enum.random(list_0))
        end
      end
    end
    state = Map.put(state, "routing_table", routing_table)
   
      {:reply, :ok, state}
    end
  
    def handle_call(:get_children, _from, state) do #  _from <= node_id
      {:reply, state["leaf_set"], state}  
    end
  
    def handle_call({:update_leaf_set_and_routing, leaf_set, nil}, _from, state) do
     
      state = Map.put(state, "leaf_set", leaf_set)
      {:reply, "ok", state}    
    end
    def handle_call({:update_leaf_set_and_routing, leaf_set, {key, value}}, _from, state) do
      state = Map.put(state, "leaf_set", leaf_set)
      routing_table = state["routing_table"]
      routing_table = Map.put(routing_table, key, value)
      state = Map.put(state, "routing_table", routing_table)
      {:reply, "ok", state}  
    end
  
    def handle_call({:update_routing_table, from_id}, _id, state) do
      
      node_id = state["node_id"]
      
      prefix_match_count = lcp([from_id | [node_id]])
  
     
      from_routing_table = state["routing_table"]
      new_routing_table = add_to_map(from_routing_table, %{}, prefix_match_count-1)
  
      
      query_node_id = from_routing_table[prefix_match_count]
      
     
      {:reply, {new_routing_table, query_node_id}, state}
    end
  
    def split(leaf_set, -1, list_0, list_1), do: {list_0, list_1, lcp(leaf_set)}
    def split(leaf_set, index, list_0, list_1) do
      leaf = Enum.at(leaf_set, index)
      ch = String.at(Atom.to_string(leaf), lcp(leaf_set))
      if ch == "0" do
        split(leaf_set, index-1, [leaf|list_0], list_1)
      else 
        split(leaf_set, index-1, list_0, [leaf|list_1])
      end    
    end
    
    def update_routing_table(_from, nil, routing_table), do: {routing_table, nil} #First Node in the network.
    def update_routing_table(node_id, start_id, routing_table) do     
      {routing_table, destination_node} = hop(node_id, start_id, routing_table, node_id)      
      {routing_table, destination_node}
    end
  
    def hop(source_node_id, nil, routing_table, _id), do: {routing_table, source_node_id}
    def hop(_source_node_id, next_hop_node_id, routing_table, id) do
      {received_routing_table, next_node_id} = GenServer.call(next_hop_node_id, {:update_routing_table, id})   # Send the node id3
      routing_table = copy_routing_table(received_routing_table, routing_table)
      hop(next_hop_node_id, next_node_id, routing_table, id)  
    end
  
    def copy_routing_table(from, to) do     
      to = Map.merge(to, from, fn _k, v1,v2 -> v1 end)    
      
      to 
    end
  
  
    def add_to_map(_from, to, -1), do: to 
    def add_to_map(from, to, n) do
      if from[n] != nil do
        to = Map.put(to, n, from[n])
      end
      add_to_map(from, to, n-1)
    end
  
    def lcp([]), do: 0
    def lcp(strs) do
     
      strs = Enum.map(strs, fn(str) -> Atom.to_string(str) end)
      min = Enum.min(strs)
      max = Enum.max(strs)
      index = Enum.find_index(0..String.length(min), fn i -> String.at(min,i) != String.at(max,i) end)
      if index, do: String.length(String.slice(min, 0, index)), else: String.length(min)
    end
  
  end