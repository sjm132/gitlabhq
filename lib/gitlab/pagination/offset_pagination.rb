# frozen_string_literal: true

module Gitlab
  module Pagination
    class OffsetPagination < Base
      attr_reader :request_context

      delegate :params, :header, :request, to: :request_context

      def initialize(request_context)
        @request_context = request_context
      end

      def paginate(relation, exclude_total_headers: false, skip_default_order: false, without_count: false, skip_pagination_check: false)
        ordered_relation = add_default_order(relation, skip_default_order: skip_default_order)

        paginate_with_limit_optimization(ordered_relation, without_count: without_count, skip_pagination_check: skip_pagination_check).tap do |data|
          add_pagination_headers(data, exclude_total_headers, without_count)
        end
      end

      private

      def paginate_with_limit_optimization(relation, without_count:, skip_pagination_check: false)
        pagination_data = if !skip_pagination_check && needs_pagination?(relation)
                            relation.page(params[:page]).per(params[:per_page])
                          else
                            relation
                          end

        return pagination_data unless pagination_data.is_a?(ActiveRecord::Relation)

        if without_count || exceeeds_count?(pagination_data)
          # The call to `total_count_with_limit` memoizes `@arel` because of a call to `references_eager_loaded_tables?`
          # We need to call `reset` because `without_count` relies on `@arel` being unmemoized
          pagination_data.reset.without_count
        else
          pagination_data
        end
      end

      def needs_pagination?(relation)
        return true unless relation.respond_to?(:current_page)
        return true if params[:page].present? && relation.current_page != params[:page].to_i
        return true if params[:per_page].present? && relation.limit_value != params[:per_page].to_i

        false
      end

      def add_default_order(relation, skip_default_order: false)
        return relation if skip_default_order

        if relation.is_a?(ActiveRecord::Relation) && relation.order_values.empty?
          relation = relation.order(:id) # rubocop: disable CodeReuse/ActiveRecord
        end

        relation
      end

      def add_pagination_headers(paginated_data, exclude_total_headers, without_count)
        Gitlab::Pagination::OffsetHeaderBuilder.new(
          request_context: self, per_page: paginated_data.limit_value, page: paginated_data.current_page,
          next_page: paginated_data.next_page, prev_page: paginated_data.prev_page,
          total: total_count(paginated_data), total_pages: total_pages(paginated_data)
        ).execute(exclude_total_headers: exclude_total_headers, data_without_counts: without_count || data_without_counts?(paginated_data))
      end

      def data_without_counts?(paginated_data)
        paginated_data.is_a?(Kaminari::PaginatableWithoutCount) || paginatable_array_exceeds_count?(paginated_data)
      end

      def paginatable_array_exceeds_count?(paginated_data)
        paginated_data.is_a?(Kaminari::PaginatableArray) &&
          paginated_data.total_count >= Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT
      end

      def total_count(paginated_data)
        paginated_data.total_count unless data_without_counts?(paginated_data)
      end

      def total_pages(paginated_data)
        return if data_without_counts?(paginated_data)

        # Ensure there is in total at least 1 page
        [paginated_data.total_pages, 1].max
      end

      def exceeeds_count?(paginated_data)
        limited_total_count = paginated_data.total_count_with_limit

        limited_total_count > Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT
      end
    end
  end
end
