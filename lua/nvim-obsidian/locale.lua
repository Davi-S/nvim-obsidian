-- Hardcoded locale data for month and weekday name translations
local M = {}

M.LOCALE_NAMES = {
    ["en-US"] = {
        month_names = {
            [1] = "january",
            [2] = "february",
            [3] = "march",
            [4] = "april",
            [5] = "may",
            [6] = "june",
            [7] = "july",
            [8] = "august",
            [9] = "september",
            [10] = "october",
            [11] = "november",
            [12] = "december",
        },
        weekday_names = {
            [1] = "sunday",
            [2] = "monday",
            [3] = "tuesday",
            [4] = "wednesday",
            [5] = "thursday",
            [6] = "friday",
            [7] = "saturday",
        },
    },
    ["pt-BR"] = {
        month_names = {
            [1] = "janeiro",
            [2] = "fevereiro",
            [3] = "março",
            [4] = "abril",
            [5] = "maio",
            [6] = "junho",
            [7] = "julho",
            [8] = "agosto",
            [9] = "setembro",
            [10] = "outubro",
            [11] = "novembro",
            [12] = "dezembro",
        },
        weekday_names = {
            [1] = "domingo",
            [2] = "segunda-feira",
            [3] = "terça-feira",
            [4] = "quarta-feira",
            [5] = "quinta-feira",
            [6] = "sexta-feira",
            [7] = "sábado",
        },
    },
}

return M
