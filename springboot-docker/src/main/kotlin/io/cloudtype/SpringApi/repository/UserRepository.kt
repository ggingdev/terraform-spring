package io.cloudtype.SpringApi.repository;

import io.cloudtype.SpringApi.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<User, Long>