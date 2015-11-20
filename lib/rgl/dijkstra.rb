require 'rgl/dijkstra_visitor'
require 'rgl/edge_properties_map'
require 'rgl/path_builder'

require 'delegate'
require 'algorithms'

module RGL

  class DijkstraAlgorithm

    # Distance combinator is a lambda that accepts the distance (usually from the source) to vertex _u_ and the weight
    # of the edge connecting vertex _u_ to another vertex _v_ and returns the distance to vertex _v_ if it's reached
    # through the vertex _u_. By default, the distance to vertex _u_ and the edge's weight are summed.
    DEFAULT_DISTANCE_COMBINATOR = lambda { |distance, edge_weight| distance + edge_weight }

    # Initializes Dijkstra's algorithm for a _graph_ with provided edges weights map.
    #
    def initialize(graph, edge_weights_map, visitor, distance_combinator = nil)
      @graph               = graph
      @edge_weights_map    = build_edge_weights_map(edge_weights_map)
      @visitor             = visitor
      @distance_combinator = distance_combinator || DEFAULT_DISTANCE_COMBINATOR
    end

    # Finds the shortest path from the _source_ to the _target_ in the graph.
    #
    # Returns the shortest path, if it exists, as an Array of vertices. Otherwise, returns nil.
    #
    def shortest_path(source, target)
      init(source)
      relax_edges(target, true)
      PathBuilder.new(source, @visitor.parents_map).path(target)
    end

    # Finds the shortest path form the _source_ to every other vertex of the graph and builds shortest paths map.
    #
    # Returns the shortest paths map that contains the shortest path (if it exists) from the source to any vertex of the
    # graph.
    #
    def shortest_paths(source)
      find_shortest_paths(source)
      PathBuilder.new(source, @visitor.parents_map).paths(@graph.vertices)
    end

    # Finds the shortest path from the _source_ to every other vertex.
    #
    def find_shortest_paths(source)
      init(source)
      relax_edges
    end

    private

    def init(source)
      @visitor.set_source(source)

      @queue = Queue.new
      @queue.push(source, 0)
    end

    def relax_edges(target = nil, break_on_target = false)
      until @queue.empty?
        puts "qb: #{@queue.to_a.map(&:vertex)}"

        u = @queue.pop
        puts "poped: #{u}"

        if break_on_target && u == target
          puts "break: #{u}"
          break
        end

        puts "ex v: #{u}"
        @visitor.handle_examine_vertex(u)

        @graph.each_adjacent(u) do |v|
          unless @visitor.finished_vertex?(v)
            puts "rel e: #{[u, v]}"
            relax_edge(u, v)
          else
            puts "else: #{[u, v]}"
          end
        end

        @visitor.color_map[u] = :BLACK
        @visitor.handle_finish_vertex(u)

        puts "qe: #{@queue.to_a.map(&:vertex)}"
      end

      puts "actions: #{@queue.actions}"
    end

    def relax_edge(u, v)
      @visitor.handle_examine_edge(u, v)

      new_v_distance = @distance_combinator.call(@visitor.distance_map[u], @edge_weights_map.edge_property(u, v))

      if new_v_distance < @visitor.distance_map[v]
        old_v_distance = @visitor.distance_map[v]

        @visitor.distance_map[v] = new_v_distance
        @visitor.parents_map[v]  = u

        if @visitor.color_map[v] == :WHITE
          @visitor.color_map[v] = :GRAY
          puts "push: #{[v, new_v_distance]}"
          @queue.push(v, new_v_distance)
        elsif @visitor.color_map[v] == :GRAY
          puts "dec: #{[v, new_v_distance]}"
          @queue.decrease_key(v, old_v_distance, new_v_distance)
        end
 
        puts "relaxed: #{[u, v]}"
        @visitor.handle_edge_relaxed(u, v)
      else
        puts "not relaxed: #{[u, v]}"
        @visitor.handle_edge_not_relaxed(u, v)
      end
    end

    def build_edge_weights_map(edge_weights_map)
      edge_weights_map.is_a?(EdgePropertiesMap) ? edge_weights_map : NonNegativeEdgePropertiesMap.new(edge_weights_map, @graph.directed?)
    end

    class Queue < SimpleDelegator # :nodoc:

      attr_reader :actions

      def initialize
        @heap = Containers::Heap.new { |a, b| a.distance < b.distance }
        @actions = []
        super(@heap)
      end

      def push(vertex, distance)
        @actions << [vertex, distance]
        @heap.push(vertex_key(vertex, distance), vertex)
      end

      def pop
        @heap.pop.tap { |v| @actions << -v }
      end

      def decrease_key(vertex, old_distance, new_distance)
        raise "wut"
        @heap.change_key(vertex_key(vertex, old_distance), vertex_key(vertex, new_distance))
      end

      def vertex_key(vertex, distance)
        VertexKey.new(vertex, distance)
      end

      def to_a
        @heap.instance_variable_get(:@stored).keys.select { |k| @heap.has_key?(k) }
      end

      VertexKey = Struct.new(:vertex, :distance)

    end

  end # class DijkstraAlgorithm

  module Graph

    # Finds the shortest path from the _source_ to the _target_ in the graph.
    #
    # If the path exists, returns it as an Array of vertices. Otherwise, returns nil.
    #
    # Raises ArgumentError if edge weight is negative or undefined.
    #
    def dijkstra_shortest_path(edge_weights_map, source, target, visitor = DijkstraVisitor.new(self))
      DijkstraAlgorithm.new(self, edge_weights_map, visitor).shortest_path(source, target)
    end

    # Finds the shortest paths from the _source_ to each vertex of the graph.
    #
    # Returns a Hash that maps each vertex of the graph to an Array of vertices that represents the shortest path
    # from the _source_ to the vertex. If the path doesn't exist, the corresponding hash value is nil. For the _source_
    # vertex returned hash contains a trivial one-vertex path - [source].
    #
    # Raises ArgumentError if edge weight is negative or undefined.
    #
    def dijkstra_shortest_paths(edge_weights_map, source, visitor = DijkstraVisitor.new(self))
      DijkstraAlgorithm.new(self, edge_weights_map, visitor).shortest_paths(source)
    end

  end # module Graph

end # module RGL

__END__

irb -Ilib -rrgl/base -rrgl/adjacency -rrgl/dijkstra

graph = RGL::AdjacencyGraph[1,2, 1,3, 1,4, 1,5, 2,6, 3,8, 5,7, 9,10, 9,11, 9,12, 10,14, 11,6, 12,13, 13,16]
graph.dijkstra_shortest_path(Hash.new(1), 6, 16)

def wut
  require 'pry'
  actions = [[6, 0], -6, [2, 1], [11, 1], -2, [1, 2], -11, [9, 2], -1, [3, 3], [4, 3], [5, 3], -9, [10, 3], [12, 3], -3, [8, 4], -5, [7, 4], -12, [13, 4], -10, [14, 4], -4, -14, -8, -7, -7]

  heap = Containers::Heap.new { |a, b| a.distance < b.distance }

  class Containers::Heap
    def vertices
      @stored.keys.select { |k| has_key?(k) }.map(&:vertex)
    end

    def stored
      @stored
    end
  end

  VertexKey = Struct.new(:vertex, :distance)

  actions.each do |action|
    if action.is_a?(Array)
      puts "pushing #{action}"
      v, d = action
      heap.push(VertexKey.new(*v, d), v)
      puts "verts: #{heap.vertices}"
      puts
      binding.pry if p == 7
    else
      puts "stored: #{heap.stored[VertexKey.new(13, 4)]}"
      p = heap.pop
      puts "popped #{p} (expected #{-action})"
      puts "verts: #{heap.vertices}"
      binding.pry if p == 7
    end
  end
end