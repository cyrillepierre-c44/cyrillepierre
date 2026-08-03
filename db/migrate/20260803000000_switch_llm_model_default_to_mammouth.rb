class SwitchLlmModelDefaultToMammouth < ActiveRecord::Migration[8.1]
  # GitHub Models expired — every remaining model is served by Mammouth. Existing rows
  # created with the old "gpt-4o" default must be remapped, otherwise they fail the
  # LLM_MODELS inclusion validation on their next update.
  def up
    change_column_default :generations, :llm_model, from: "gpt-4o", to: "gemini-3.5-flash"
    execute "UPDATE generations SET llm_model = 'gemini-3.5-flash' WHERE llm_model NOT IN " \
            "('gemini-3.5-flash', 'claude-sonnet-4-6', 'claude-opus-4-8', 'mistral-large-3', 'gpt-5.4')"
  end

  def down
    change_column_default :generations, :llm_model, from: "gemini-3.5-flash", to: "gpt-4o"
  end
end
