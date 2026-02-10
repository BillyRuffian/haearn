# frozen_string_literal: true

# Controller for managing blocks within workout templates
class TemplateBlocksController < ApplicationController
  before_action :set_template
  before_action :set_template_block, only: [ :destroy ]

  # DELETE /workout_templates/:workout_template_id/blocks/:id
  def destroy
    @template_block.destroy
    redirect_to @template, notice: 'Block removed from template.'
  end

  private

  def set_template
    @template = Current.user.workout_templates.find(params[:workout_template_id])
  end

  def set_template_block
    @template_block = @template.template_blocks.find(params[:id])
  end
end
