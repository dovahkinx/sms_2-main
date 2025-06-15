package com.dovahkin.sms_guard

import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.dovahkin.sms_guard.Message


val database_name = "SpamSMS"
val table_name = "Messages"
val col_id = "id"
val col_address = "address"
val col_message = "message"


class DBHelper( var context: Context):SQLiteOpenHelper(context, database_name, null, 1) {
    override fun onCreate(db: SQLiteDatabase?) {
        val createTable = "CREATE TABLE " + table_name + " (" +
                col_id + " INTEGER PRIMARY KEY AUTOINCREMENT," +
                col_address + " VARCHAR(256)," +
                col_message + " VARCHAR(256))"

        db?.execSQL(createTable)
    }


    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {
        TODO("Not yet implemented")
    }
    fun insertData(message: String, address: String) {
        val database = this.writableDatabase
        
        // Önce aynı mesaj ve adres kombinasyonunu kontrol et
        val checkQuery = "SELECT * FROM $table_name WHERE $col_address = ? AND $col_message = ?"
        val cursor = database.rawQuery(checkQuery, arrayOf(address, message))
        
        // Eğer bu mesaj ve adres kombinasyonu zaten varsa, yeni kayıt eklemeye gerek yok
        if (cursor.count > 0) {
            cursor.close()
            return
        }
        cursor.close()
        
        // Sadece mesaj daha önce kaydedilmemişse ekle
        val contentValues = ContentValues()
        contentValues.put(col_address, address)
        contentValues.put(col_message, message)
        database.insert(table_name, null, contentValues)
    }

    @SuppressLint("Range")
    fun readData(): MutableList<Message>{
        var list: MutableList<Message> = ArrayList()
        val db = this.readableDatabase
        val query = "Select * from " + table_name
        val result = db.rawQuery(query, null)
        if (result.moveToFirst()){
            do {
                var message = Message()
                message.id = result.getString(result.getColumnIndex(col_id)).toInt()
                message.address = result.getString(result.getColumnIndex(col_address))
                message.message = result.getString(result.getColumnIndex(col_message))
                list.add(message)
            }while (result.moveToNext())
        }
        result.close()
        db.close()
        return list
    }

}

