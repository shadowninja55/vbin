import vweb
import rand
import os
import sqlite
import time

#flag -D SQLITE_THREADSAFE=1

struct App {
	vweb.Context
mut:
	db sqlite.DB
}

struct Upload {
	id int
	code string
	created string
	dead int
}

fn cleanup_uploads() {
	for {
		println("cleaning out uploads...")

		db := sqlite.connect("db/vbin.sqlite") or {
			panic("vbin.sqlite not found!")
		}

		db.exec("UPDATE Upload SET dead = 1 WHERE created <= datetime('now', '-24 hours')")

		dead_rows := sql db {
			select from Upload where dead == 1
		}

		for row in dead_rows {
			os.rm("uploads/${row.code}.txt") or {
				eprintln("${row.code}.txt not found, skipping deletion...")
				continue
			}
		}

		sql db {
			delete from Upload where dead == 1
		}

		time.sleep(3600)
	}
}

fn gen_code(db sqlite.DB) string {
	chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	for {
		mut bytes := []byte{len: 7}

		for idx in 0..7 {
			bytes[idx] = chars[rand.intn(chars.len)]
		}

		code := bytes.bytestr()

		entries := sql db {
			select from Upload where code == code
		}

		if entries.len == 0 {
			return code
		}
	}

	return ""
}

[get]
["/api/fetch"] 
fn (mut app App) fetch() vweb.Result {
	code := app.query["code"]

	if _unlikely_(code == "") {
		return app.text("no code was supplied")
	} else {
		entries := sql app.db {
			select from Upload where code == code
		}

		if entries.len == 0 {
			return app.text("an invalid code was supplied")
		}
	}

	content := os.read_file("uploads/${code}.txt") or {
		return app.server_error(500)
	}

	return app.text(content)
}

[post]
["/api/upload"]
fn (mut app App) upload() vweb.Result {
	content := app.form["content"]

	if _unlikely_(content == "") {
		return app.text("no content was supplied for the upload")
	}

	code := gen_code(app.db)

	upload := Upload {
		code: code
		created: time.now().format_ss_milli()
	}

	sql app.db {
		insert upload into Upload
	}

	os.write_file("uploads/${code}.txt", content) or {
		return app.server_error(500) 
	}

	return app.ok(code)
}

pub fn (mut app App) init_once() {
	app.db = sqlite.connect("db/vbin.sqlite") or {
		panic("vbin.sqlite not found!") 
	}

	app.db.exec("CREATE TABLE IF NOT EXISTS Upload (id integer primary key, 
		code string, created datetime, dead integer default 0)")

	go cleanup_uploads()
}

fn main() {
	vweb.run<App>(80)
}