module Storange
  class << self
  end

  def connection
    @connection ||= begin
      db = SQLite3::Database.new 'vox.db'

      db.execute <<-WHOMP
        create table if not exists voxes (
          id  integer primary key autoincrement,
          content text
        );
      WHOMP

      db.execute <<-BYAH
        create table if not exists users (
          id            integer primary key autoincrement,
          username      text,
          password_salt text,
          password_hash text
        );
      BYAH

      db
    end
  end

  def fetch(col, val)
    if res = connection.execute(get(col), val)
      first, second, *rest = res
      hash = Hash[first.map(&:to_sym).zip(second)]
      self.initialize hash
    end
  end

  def save
    pre = if block_given?
            yield
          else
            true
          end

    if pre
      update if connection.execute exists?, self.resource_id
      connection.execute post(self.cols), self.vals
    end
  end

  def update
    connection.execute patch(self.cols, self.vals), self.resource_id
  end

  def destroy
    connect.execute delete, self.resource_id
  end

  private

  def get(col)

  end

  def exists?(db)
    "select exists (select 1 from #{db} where resource_id = ?);"
  end

  def post(db, cols)
    "insert into #{db}(#{cols.join ','}) values(#{('?,' * cols.count)[0...-1]});"
  end

  def patch(db, cols, vals)
    updates = cols.zip(vals).map do |inner_ary|
      inner_ary.join '='
    end.join ','

    "update #{db} set #{updates} where resource_id = ?"
  end

  def delete(db)
    "delete from #{db} where resource_id = ?"
  end
end
