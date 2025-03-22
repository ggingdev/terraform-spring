package io.cloudtype.SpringApi.controller;

import io.cloudtype.SpringApi.model.User
import io.cloudtype.SpringApi.service.UserService
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/users")
class UserController(private val userService: UserService) {

    @GetMapping
    fun getAllUsers(): List<User> = userService.getAllUsers()

    @GetMapping("/{id}")
    fun getUserById(@PathVariable id: Long): User = userService.getUserById(id)

    @PostMapping
    fun createUser(@RequestBody user: User): User = userService.createUser(user)

    @PutMapping("/{id}")
    fun updateUser(@PathVariable id: Long, @RequestBody user: User): User = userService.updateUser(id, user)

    @DeleteMapping("/{id}")
    fun deleteUser(@PathVariable id: Long): ResponseEntity<Void> {
        userService.deleteUser(id)
        return ResponseEntity.noContent().build()
    }
}