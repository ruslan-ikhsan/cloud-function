# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project_id
  region  = var.region
}

#Generates archive of source code
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "../src"
  output_path = "/tmp/function.zip"
}

#Declaring two Google Cloud Storage buckets respectively to store the code of the Cloud Function and to upload files
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-function1"
  location = var.region
}

resource "google_storage_bucket" "input_bucket" {
  name     = "${var.project_id}-input1"
  location = var.region
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name

  depends_on   = [
    google_storage_bucket.function_bucket,
    data.archive_file.source
  ]
}

resource "google_cloudfunctions_function" "tob_cloud_function" {
  name                  = "function-trigger1t-on-gcs"
  runtime               = "python37"  # of course changeable
  service_account_email = "my-test-project-364606@appspot.gserviceaccount.com"

  # Get the source code of the cloud function as a Zip compression
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.zip.name

  # Name of the function that will be executed when the Google Cloud Function is triggered (def hello_gcs)
  entry_point = "hello_gcs"

  # A source that fires events in response to a condition in another service.
  # Any file uploaded to bucket will trigger the Cloud Function
  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = "${var.project_id}-input"
  }

  # Dependencies are automatically inferred so these lines can be deleted
  depends_on            = [
    google_storage_bucket.function_bucket,
    google_storage_bucket_object.zip
  ]
}

# Enable API for Cloud Build
resource "google_project_service" "cloud_build" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    google_cloudfunctions_function.tob_cloud_function
  ]
}

# Enable API for Cloud Function
resource "google_project_service" "cloud_function" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
  disable_dependent_services = true
  depends_on = [
    google_cloudfunctions_function.tob_cloud_function
  ]
}
