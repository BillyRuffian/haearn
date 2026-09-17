# frozen_string_literal: true

# Controller for managing blocks within workout templates
class TemplateBlocksController < ApplicationController
  before_action :set_template
  before_action :set_template_block, only: [ :destroy ]

  # DELETE /workout_templates/:workout_template_id/blocks/:id
  def destroy
    @template_block.remove_from_template!
    redirect_to @template, notice: 'Block removed from template.', status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @template, alert: error.record.errors.full_messages.to_sentence, status: :see_other
  end

  private

  def set_template
    @template = Current.user.workout_templates.find(params[:workout_template_id])
  end

  def set_template_block
    @template_block = @template.template_blocks.find(params[:id])
  end
end
