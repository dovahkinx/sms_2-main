package com.dovahkin.sms_guard

class Message {
    var id: Int = 0

    var address: String? = null
    var message: String? = null

constructor(    id: Int,

    address: String?,
    message: String?) {
    this.id = id

    this.address = address
    this.message = message
}
    constructor(){}
}