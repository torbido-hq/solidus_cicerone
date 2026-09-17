# frozen_string_literal: true

module Spree
  module Admin
    class CiceroneController < Spree::Admin::BaseController
      def show
        @settings = SolidusCicerone.configuration.to_h.merge(
          serve_url: SolidusCicerone.serve_url,
          serve_token: SolidusCicerone.serve_token,
          events_token: SolidusCicerone.events_token,
          trigger_url: SolidusCicerone.trigger_url,
          trigger_token: SolidusCicerone.trigger_token,
          dashboard_url: SolidusCicerone.dashboard_url
        )
      end

      def update
        SolidusCicerone::Settings.set(settings_params.to_h)
        flash[:success] = I18n.t("spree.admin.cicerone.settings_saved")
        redirect_to spree.admin_cicerone_path
      end

      def export
        SolidusCicerone.enqueue_export
        flash[:success] = I18n.t("spree.admin.cicerone.export_queued")
        redirect_to spree.admin_cicerone_path
      end

      def retrain
        SolidusCicerone.enqueue_retrain
        flash[:success] = I18n.t("spree.admin.cicerone.retrain_queued")
        redirect_to spree.admin_cicerone_path
      end

      private

      def settings_params
        params.require(:cicerone).permit(
          :serve_url,
          :serve_token,
          :events_token,
          :trigger_url,
          :trigger_token,
          :dashboard_url,
          :cache_ttl,
          :default_limit,
          :enabled
        )
      end
    end
  end
end
