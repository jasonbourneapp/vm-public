# Completion для команды rp (replacer)

# Функция для получения файлов в текущей директории
function __rp_list_files
    find . -maxdepth 3 -type f \( -name "*.go" -o -name "*.ts" -o -name "*.js" \) 2>/dev/null | sed 's|^\./||'
end

# Первый аргумент - целевой файл (если используется буфер обмена)
complete -c rp -n '__fish_is_first_arg' -a '(__rp_list_files)' -d 'Целевой файл'

# Второй аргумент - целевой файл (если первый - исходный файл)
complete -c rp -n '__fish_is_nth_token 2' -a '(__rp_list_files)' -d 'Целевой файл'

# Разделитель --
complete -c rp -n '__fish_is_first_arg' -a '--' -d 'Разделитель аргументов'

# Опции
complete -c rp -l clipboard -s c -d 'Использовать буфер обмена как источник'
complete -c rp -l help -s h -d 'Показать справку'
