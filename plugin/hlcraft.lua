if vim.fn.exists(':Hlcraft') ~= 2 then
  vim.api.nvim_create_user_command('Hlcraft', function()
    local hlcraft = require('hlcraft')
    if not hlcraft.is_setup() then
      hlcraft.setup()
    end
    hlcraft.open()
  end, {
    nargs = 0,
    desc = 'Open the Hlcraft interactive highlight explorer',
  })
end
