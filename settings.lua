data:extend({
    {
        name = 'radarmarker-announce-placement',
	order = 'a',
        type = 'bool-setting',
        setting_type = 'runtime-global',
        default_value = true,
    },
    {
        name = 'radarmarker-announce-removal',
	order = 'b',
        type = 'bool-setting',
        setting_type = 'runtime-global',
        default_value = true,
    },
    {
        name = 'radarmarker-mark-placed-radars',
	order = 'c',
        type = 'string-setting',
        setting_type = 'runtime-global',
        default_value = "All",
        allowed_values = {"All", "Misalligned", "None"}
    },
    {
        name = 'radarmarker-mark-planned-radars',
	order = 'd',
        type = 'string-setting',
        setting_type = 'runtime-global',
        default_value = "All",
        allowed_values = {"All", "Missing", "None"}
    },
    {
        name = 'radarmarker-label-planned-radars',
	order = 'e',
        type = 'bool-setting',
        setting_type = 'runtime-global',
        default_value = true,
    },
    {
        name = 'radarmarker-planned-radars-spacing',
	order = 'f',
        type = 'int-setting',
        setting_type = 'runtime-global',
        default_value = 224,
	minimum_value = 32,
	maximum_value = 999,
    },
    --[[
    -- Possible future enhancement - align the markers to the chunk grid,
    -- even if the spacing is not a multiple of the chunk size. (i.e. 32)
    {
        name = 'radarmarker-chunk-align-planned-radars',
	order = 'g',
        type = 'bool-setting',
        setting_type = 'runtime-global',
        default_value = true,
    },
    ]]
    {
        name = 'radarmarker-planned-radars-x-offset',
	order = 'h',
        type = 'int-setting',
        setting_type = 'runtime-global',
        default_value = 16,
	minimum_value = -999,
	maximum_value = 999,
    },
    {
        name = 'radarmarker-planned-radars-y-offset',
	order = 'i',
        type = 'int-setting',
        setting_type = 'runtime-global',
        default_value = 16,
	minimum_value = -999,
	maximum_value = 999,
    },
})
