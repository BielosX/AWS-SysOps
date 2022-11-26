import org.apache.commons.cli.DefaultParser
import org.apache.commons.cli.Options
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.CompleteMultipartUploadRequest
import software.amazon.awssdk.services.s3.model.CompletedMultipartUpload
import software.amazon.awssdk.services.s3.model.CompletedPart
import software.amazon.awssdk.services.s3.model.CreateMultipartUploadRequest
import software.amazon.awssdk.services.s3.model.UploadPartRequest
import java.io.File
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.Future

class S3MultipartUploader {
    private val s3Client = S3Client.builder().build()
    private val pool = Executors.newFixedThreadPool(8)

    companion object {
        // One part should be 5MiB minimum
        const val BUFFER_SIZE = 5 * 1024 * 1024
    }

    fun close() {
        pool.shutdown()
    }

    fun upload(bucket: String, filePath: String, bucketKey: String) {
        val stream = File(filePath).inputStream().buffered()
        val multipartUploadRequest = CreateMultipartUploadRequest.builder()
            .bucket(bucket)
            .key(bucketKey)
            .build()
        val multipartResponse = s3Client.createMultipartUpload(multipartUploadRequest)
        var bytes = stream.readNBytes(BUFFER_SIZE)
        var partNumber = 1
        val futures: ArrayList<Future<*>> = ArrayList()
        val completedUploads: ConcurrentLinkedQueue<CompletedPart> = ConcurrentLinkedQueue()
        while (bytes.isNotEmpty()) {
            val number = partNumber
            val body = bytes.clone()
            val future = pool.submit {
                val uploadRequest = UploadPartRequest.builder()
                    .bucket(bucket)
                    .key(bucketKey)
                    .uploadId(multipartResponse.uploadId())
                    .partNumber(number)
                    .build()
                val response = s3Client.uploadPart(uploadRequest, RequestBody.fromBytes(body))
                completedUploads.add(CompletedPart.builder()
                    .partNumber(number)
                    .eTag(response.eTag())
                    .build())
            }
            futures.add(future)
            partNumber++
            bytes = stream.readNBytes(BUFFER_SIZE)
        }
        var allCompleted = false
        while (!allCompleted) {
            val completed = futures.map(Future<*>::isDone).count { it }
            allCompleted = completed == futures.size
            print('\r')
            print("$completed / ${futures.size} finished")
            if (allCompleted) {
                print('\n')
            } else {
                Thread.sleep(1_000)
            }
        }
        val completeMultipartRequest = CompleteMultipartUploadRequest.builder()
            .bucket(bucket)
            .uploadId(multipartResponse.uploadId())
            .key(bucketKey)
            .multipartUpload(CompletedMultipartUpload.builder()
                .parts(completedUploads.toList().sortedBy(CompletedPart::partNumber))
                .build())
            .build()
        s3Client.completeMultipartUpload(completeMultipartRequest)
        println("Upload completed")
    }
}

fun main(args: Array<String>) {
    val uploader = S3MultipartUploader()
    val options = Options()
    options.addOption("f", "file", true, "File path")
    options.addOption("k", "key", true, "S3 key")
    options.addOption("b", "bucket", true, "S3 Bucket")
    val parser = DefaultParser()
    val cmd = parser.parse(options, args)
    val bucket = cmd.getOptionValue("bucket")
    val key = cmd.getOptionValue("key")
    val file = cmd.getOptionValue("file")
    uploader.upload(bucket, file, key)
    uploader.close()
}