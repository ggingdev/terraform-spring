package io.cloudtype.SpringApi.service;


import io.cloudtype.SpringApi.model.User
import io.cloudtype.SpringApi.repository.UserRepository;
import org.springframework.stereotype.Service


@Service
class UserService(private val userRepository:UserRepository) {

    fun getAllUsers(): List<User> = userRepository.findAll()

    fun getUserById(id: Long): User = userRepository.findById(id).orElseThrow { Exception("User not found") }

    fun createUser(user: User): User = userRepository.save(user)

    fun updateUser(id: Long, userDetails: User): User {
        val user = getUserById(id)
        val updatedUser = user.copy(name = userDetails.name, email = userDetails.email)
        return userRepository.save(updatedUser)
    }

    fun deleteUser(id: Long) {
        val user = getUserById(id)
        userRepository.delete(user)
    }
}
