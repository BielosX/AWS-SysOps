import org.apache.commons.cli.DefaultParser
import org.apache.commons.cli.Options
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.dynamodb.DynamoDbClient
import software.amazon.awssdk.services.dynamodb.model.AttributeValue
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.GetObjectRequest
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import java.io.File
import java.lang.IllegalStateException
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.*
import javax.crypto.KeyGenerator

class S3Saver(private val bucket: String, private val table: String) {
    private val s3Client = S3Client.builder().build()
    private val dynamoDbClient = DynamoDbClient.builder().build()
    private val keyGenerator = KeyGenerator.getInstance("AES")

    companion object {
        const val PATH_KEY_NAME = "path"
        const val KEY_KEY_NAME = "key" // XD
        const val MD5_KEY_NAME = "md5"
    }

    init {
        keyGenerator.init(256, SecureRandom())
    }

    fun putObject(file: String, path: String) {
        val content = File(file).readText(Charsets.UTF_8)
        val key = keyGenerator.generateKey()
        val encodedKey = Base64.getEncoder().encodeToString(key.encoded)
        val messageDigest = MessageDigest.getInstance("MD5")
        messageDigest.update(key.encoded)
        val encodedMessageDigest = Base64.getEncoder().encodeToString(messageDigest.digest())
        val putObjectRequest = PutObjectRequest.builder()
            .key(path)
            .bucket(bucket)
            .sseCustomerAlgorithm("AES256")
            .sseCustomerKey(encodedKey)
            .sseCustomerKeyMD5(encodedMessageDigest)
            .build()
        s3Client.putObject(putObjectRequest, RequestBody.fromString(content))
        val putItemRequest = PutItemRequest.builder()
            .tableName(table)
            .item(mapOf(
                PATH_KEY_NAME to AttributeValue.fromS(path),
                KEY_KEY_NAME to AttributeValue.fromS(encodedKey),
                MD5_KEY_NAME to AttributeValue.fromS(encodedMessageDigest)
            ))
            .build()
        dynamoDbClient.putItem(putItemRequest)
    }

    fun getObject(path: String) {
        val getItemRequest = GetItemRequest.builder()
            .tableName(table)
            .key(mapOf(
                PATH_KEY_NAME to AttributeValue.fromS(path)
            ))
            .build()
        val response = dynamoDbClient.getItem(getItemRequest)
        if (!response.hasItem()) {
            throw IllegalStateException("Key not found for path $path")
        }
        val key = response.item()["key"]!!.s()
        val md5 = response.item()["md5"]!!.s()
        val getObjectRequest = GetObjectRequest.builder()
            .key(path)
            .bucket(bucket)
            .sseCustomerAlgorithm("AES256")
            .sseCustomerKey(key)
            .sseCustomerKeyMD5(md5)
            .build()
         val scanner = Scanner(s3Client.getObject(getObjectRequest)).useDelimiter("\\A")
        val result = if (scanner.hasNext()) scanner.next() else ""
        print(result)
    }
}

fun main(args: Array<String>) {
    val options = Options()
    options.addOption("f", "file", true, "File path")
    options.addOption("p", "path", true, "S3 path")
    options.addOption("t", "table", true, "DynamoDB table")
    options.addOption("b", "bucket", true, "S3 Bucket")
    val parser = DefaultParser()
    val cmd = parser.parse(options, args)
    val bucket = cmd.getOptionValue("bucket")
    val saver = S3Saver(bucket, cmd.getOptionValue("table"))
    val path = cmd.getOptionValue("path")
    val file = cmd.getOptionValue("file")
    if (cmd.args.isEmpty()) {
        throw IllegalArgumentException("Action should be put or get")
    }
    when (cmd.args[0]) {
        "put" -> saver.putObject(file, path)
        "get" -> saver.getObject(path)
        else -> {
            throw IllegalArgumentException("Action should be put or get")
        }
    }
}