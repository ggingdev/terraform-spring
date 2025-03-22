package io.cloudtype.SpringApi

import io.cloudtype.SpringApi.model.User
import io.cloudtype.SpringApi.repository.UserRepository
import org.springframework.boot.CommandLineRunner
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration


@Configuration
class DataInitializer {

    @Bean
    fun init(userRepository: UserRepository) = CommandLineRunner {
        val user = User(name = "Admin", email = "admin@example.com")
        userRepository.save(user)
    }
}