# Claude Code wrapper: work mode (Azure Foundry) by default, -p for personal (Anthropic)
# Disabled 2026-08-11 — commented out regardless of profile, not removed from
# any profile's module list, so this file can keep being sourced under
# FISH_WORK without the alias actually taking effect.
# function claude --wraps='command claude' --description 'Claude Code with work/personal mode'
#     if test "$argv[1]" = "-p"
#         CLAUDE_CODE_IHR_PROFILE=personal \
#         command claude $argv[2..]
#     else
#         CLAUDE_CODE_USE_FOUNDRY=1 \
#         ANTHROPIC_FOUNDRY_BASE_URL=https://ai-foundry-axpo-ts-resource.services.ai.azure.com/anthropic \
#         CLAUDE_CODE_IHR_PROFILE=work \
#         command claude $argv
#     end
# end
