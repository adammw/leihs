module Procurement
  module Csv
    extend ActiveSupport::Concern

    included do
      def self.csv_export(requests, current_user)
        Export.csv_string *header_and_objects(requests, current_user)
      end

      def self.excel_export(requests, current_user)
        Export.excel_string *header_and_objects(requests, current_user),
                            worksheet_name: _('Requests')
      end

      def self.header_and_objects(requests, current_user)
        objects = []
        requests.each do |request|
          objects << request.csv_columns(current_user)
        end
        header = objects.flat_map(&:keys).uniq
        [header, objects]
      end

      # rubocop:disable Metrics/MethodLength
      def csv_columns(current_user)
        { _('Budget period') => budget_period.to_s,
          _('Main category') => category.main_category.name,
          _('Subcategory') => category.name,
          _('Requester') => user,
          _('Department') => organization.parent.name,
          _('Organisation') => organization.name,
          _('Article or Project') => article_name,
          _('Article nr. or Producer nr.') => article_number,
          _('Supplier') => supplier_name,
          _('Requested quantity') => requested_quantity,
          _('Approved quantity') => \
            authorize_value(_('Approved quantity'),
                            approved_quantity,
                            current_user),
          _('Order quantity') => \
            authorize_value(_('Order quantity'),
                            order_quantity,
                            current_user),
          format('%s %s', _('Price'), _('incl. VAT')) => price,
          format('%s %s', _('Total'), _('incl. VAT')) => total_price(current_user),
          _('State') => _(state(current_user).to_s.humanize),
          _('Priority') => _(priority.humanize),
          _("Inspector's priority") => \
            authorize_value(_("Inspector's priority"),
                            _(inspector_priority.humanize),
                            current_user),
          format('%s / %s', _('Replacement'), _('New')) => \
                                  replacement ? _('Replacement') : _('New'),
          _('Receiver') => receiver,
          _('Point of Delivery') => location_name,
          _('Motivation') => motivation,
          _('Inspection comment') => \
            authorize_value(_('Inspection comment'),
                            inspection_comment,
                            current_user)
        }
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      def authorize_value(column, value, current_user)
        value if \
          case column
          when _('Approved quantity')
            Procurement::Access.admin?(current_user) or
              Procurement::Category.inspector_of_any_category?(current_user) or
              (requested_by?(current_user) and budget_period.past?)
          when _('Inspection comment')
            Procurement::Access.admin?(current_user) or
              Procurement::Category.inspector_of_any_category?(current_user) or
              (requested_by?(current_user) and budget_period.past?)
          when _('Order quantity')
            Procurement::Access.admin?(current_user) or
              Procurement::Category.inspector_of_any_category?(current_user)
          when _("Inspector's priority")
            Procurement::Access.admin?(current_user) or
              Procurement::Category.inspector_of_any_category?(current_user)
          end
      end
      # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    end

  end
end
