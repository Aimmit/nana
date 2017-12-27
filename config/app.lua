return {
    env = 'dev', -- dev/prod
    host = '127.0.0.1',
    port = 3306,
    db_name = 'hack',
    user = 'root',
    password = 'root',
    db_timeout = 10000,
    pool_timeout = 10000,
    pool_size = 10000,
    session_lifetime = 3600 * 24 * 30, --sec
    user_table_name = 'users',
    login_id = 'email', -- login method use email/username/phone...etc
    time_zone = 'UTC+8',
}
