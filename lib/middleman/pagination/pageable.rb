module Middleman
  module Pagination
    class Pageable

      attr_reader :name

      def initialize(name, &block)
        @name = name
        @set = block
      end

      def new_resources(extension_context, resources)
        pagination_indexes(resources).map do |resource|
          new_pages_for_index(extension_context, resource, resources)
        end.compact
      end

      private

      def set(extension_context, resources, index)
        result = OpenStruct.new(resources: resources, data: extension_context.data).instance_eval(&@set)
        
        sort_order = pagination_data(index, :sort_order)
        sort_by = pagination_data(index, :sort_by)
        sort_locals_variable = pagination_data(index, :sort_locals_variable)

        if sort_by && sort_order && sort_locals_variable
          if sort_order == :desc
            result.sort do |a, b|
              b.locals[sort_locals_variable.to_sym][sort_by].to_time.to_i <=> a.locals[sort_locals_variable.to_sym][sort_by].to_time.to_i
            end
          else
            result.sort do |a, b|
              a.locals[sort_locals_variable.to_sym][sort_by].to_time.to_i <=> b.locals[sort_locals_variable.to_sym][sort_by].to_time.to_i
            end
          end
        else
          result
        end
      end

      def pagination_indexes(resources)
        Enumerator.new do |enum| 
          resources.each do |resource|
            if !resource.ignored? && pagination_data(resource, :for) == name.to_s
              enum.yield resource
            end
          end
        end
      end

      def new_pages_for_index(extension_context, index, resources)
        symbolic_replacement_path = pagination_data(index, :path)

        pageable_context = PageableContext.new(
          per_page: pagination_data(index, :per_page) || 20,
          set: set(extension_context, resources, index),
          index_resources: [index]
        )

        add_pagination_to(index, pageable_context: pageable_context, page_num: 1)

        (2..pageable_context.total_page_num).map do |page_num|
          new_index = IndexPage.new(extension_context,
                                    index,
                                    pageable_context,
                                    page_num,
                                    symbolic_replacement_path,
                                    index.metadata[:locals]).resource

          pageable_context.index_resources << new_index

          new_index
        end
      end

      def add_pagination_to(resource, attributes = {})
        in_page_context = InPageContext.new(attributes)
        resource.add_metadata(locals: { 'pagination2' => in_page_context })
      end
      
      def pagination_data(resource, key)
        keys = [:pagination2, key]

        [resource.data, resource.metadata[:options]].inject(nil) do |result, data_source|
          result or keys.inject(data_source) { |source, key| source.try(:[], key) }
        end
      end

    end
  end
end