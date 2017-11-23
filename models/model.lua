local Database = require('lib.database')
local Validator = require('lib.validator')
local config = require('config.app')
local common = require("lib.common")

local _M = {}

local mt = { __index = _M }

Database = Database:new(config)

function _M:all()
    return Database:query('select * from '..self.table)
end

function _M:where(column,operator,value)
	if not self.query_sql then
		self.query_sql = 'select * from '..self.table..' where '..column..operator..ngx.quote_sql_str(value)
	elseif string.sub(self.query_sql,1,6) == 'update' then
		self.query_sql = self.query_sql..' where '..column..operator..ngx.quote_sql_str(value)
	else
		self.query_sql = self.query_sql..' and '..column..operator..ngx.quote_sql_str(value)
	end
	return self
end

function _M:orwhere(column,operator,value)
	if not self.query_sql then
		return ngx.log(ngx.ERROR,'orwhere function need a query_sql prefix')
	else
		self.query_sql = self.query_sql..' or '..column..operator..ngx.quote_sql_str(value)
	end
	return self
end

function _M:first()
	if not self.query_sql then
		ngx.log(ngx.ERROR,'do not have query sql str')
		return
	end
	local sql = self.query_sql
	-- common:log(sql)
	self.query_sql = nil
	res = Database:query(sql)
	if table.getn(res) > 0 then
		return res[1]
	else
		return false
	end
end

function _M:find(id,column)
    column = column or 'id'
    return Database:query('select * from '..self.table..' where '..column..'='..ngx.quote_sql_str(id)..' limit 1')
end

function _M:insert(data)
	local columns,values
	for column,value in pairs(data) do
		if not columns then
			columns = column
			values = ngx.quote_sql_str(value)
		else
			columns = columns..','..column
			values = values..','..ngx.quote_sql_str(value)
		end
	end
	return Database:execute('insert ignore into '..self.table..'('..columns..') values('..values..')')
end

function _M:update(data)
	local str = nil
	if not self.query_sql then
		for column,value in pairs(data) do
			if not str then
				str = column..'='..ngx.quote_sql_str(value)
			else
				str = str..','..column..'='..ngx.quote_sql_str(value)
			end
		end
		self.query_sql = 'update '..self.table..' set '..str
		return self
	end
	return ngx.log(ngx.ERROR,'update function have to called first')
end

function _M:query(sql)
	if not sql then
		if not self.query_sql then
			return ngx.log(ngx.ERROR,'query() function need sql to query')
		end
		return Database:execute(self.query_sql)
	end
	return Database:execute(sql)
end

function _M:new(table)
	return setmetatable({
		table = table,
		query_sql = nil
		},mt)
end

return _M
