if not IsDuplicityVersion() then return {} end

local inventory = require 'bridge.inventory'

local function ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `snowy_snow_zones` (
            `id`      INT          NOT NULL AUTO_INCREMENT,
            `label`   VARCHAR(64)  NOT NULL DEFAULT '',
            `x`       FLOAT        NOT NULL,
            `y`       FLOAT        NOT NULL,
            `z`       FLOAT        NOT NULL,
            `radius`  FLOAT        NOT NULL,
            `piles`   INT          NOT NULL,
            `respawn` INT          NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

return {
    ensureSchema = ensureSchema,
    hasItem      = inventory.hasItem,
    removeItem   = inventory.removeItem,
    addItem      = inventory.addItem,
    getSlot      = inventory.getSlot,
}
