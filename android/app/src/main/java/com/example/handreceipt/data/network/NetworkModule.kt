package com.example.handreceipt.data.network

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.TypeAdapter
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import com.google.gson.stream.JsonWriter
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.CookieJar
import okhttp3.JavaNetCookieJar
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.IOException
import java.net.CookieManager
import java.util.UUID
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    // Base URL of the Go backend
    private const val BASE_URL = "http://10.0.2.2:8080/api/" // 10.0.2.2 for Android Emulator accessing localhost

    @Provides
    @Singleton
    fun provideHttpLoggingInterceptor(): HttpLoggingInterceptor {
        return HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY // Log request/response bodies
        }
    }

    // Provides the CookieManager as a singleton.
    @Provides
    @Singleton
    fun provideCookieManager(): CookieManager {
        return CookieManager()
    }

    // Provides the CookieJar implementation using the CookieManager.
    @Provides
    @Singleton
    fun provideCookieJar(cookieManager: CookieManager): CookieJar {
        return JavaNetCookieJar(cookieManager)
    }

    // Provides the OkHttpClient instance.
    @Provides
    @Singleton
    fun provideOkHttpClient(
        loggingInterceptor: HttpLoggingInterceptor,
        cookieJar: CookieJar
    ): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor) // Add logging
            .cookieJar(cookieJar) // Add cookie handling
            .connectTimeout(30, TimeUnit.SECONDS) // Standard timeouts
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    // Custom TypeAdapter for UUID (kept private, used in Gson provider)
    private val uuidTypeAdapter = object : TypeAdapter<UUID>() {
        @Throws(IOException::class)
        override fun write(out: JsonWriter, value: UUID?) {
            out.value(value?.toString())
        }

        @Throws(IOException::class)
        override fun read(input: JsonReader): UUID? {
            if (input.peek() == JsonToken.NULL) {
                input.nextNull()
                return null
            }
            val uuidString = input.nextString()
            return try {
                UUID.fromString(uuidString)
            } catch (e: IllegalArgumentException) {
                println("Error parsing UUID string: $uuidString")
                null
            }
        }
    }

    // Provides the configured Gson instance.
    @Provides
    @Singleton
    fun provideGson(): Gson {
        return GsonBuilder()
            .setDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'") // Handles Go's time.Time (UTC)
            .registerTypeAdapter(UUID::class.java, uuidTypeAdapter)
            .create()
    }

    // Provides the Retrofit instance.
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient, gson: Gson): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson)) // Use configured Gson
            .build()
    }

    // Provides the ApiService instance using Retrofit.
    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
} 