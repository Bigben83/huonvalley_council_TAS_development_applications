require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'

# Initialize the logger
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://www.huonvalley.tas.gov.au/development/planning/advertised-applications/'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create the table if it doesn't exist
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS huon_valley (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = ''

# Step 4: Extract the data from the page
applications = doc.css('.accordion-grid-item')

applications.each_with_index do |application, index|
  # Extract the application details
  council_reference = application.at_css('.accordion-grid-item__title') ? application.at_css('.accordion-grid-item__title').text.strip : nil
  description = application.at_css('.accordion-grid-item__description') ? application.at_css('.accordion-grid-item__description').text.strip : nil
  documents_link = application.at_css('.plan-file-list__item') ? application.at_css('.plan-file-list__item')['href'] : nil

  # Extract the application and closing date from the description or other parts
  date_received = description.match(/(\d{1,2} [A-Za-z]+ \d{4})/) ? Date.strptime(description.match(/(\d{1,2} [A-Za-z]+ \d{4})/)[1], '%d %B %Y').strftime('%Y-%m-%d') : nil
  on_notice_to = description.match(/(\d{1,2} [A-Za-z]+ \d{4})/) ? Date.strptime(description.match(/(\d{1,2} [A-Za-z]+ \d{4})/)[1], '%d %B %Y').strftime('%Y-%m-%d') : nil

  date_scraped = Date.today.to_s

  # Log the extracted data for debugging purposes
  logger.info("Extracted Data: #{council_reference}, #{description}, #{documents_link}, #{council_reference}, #{date_received}, #{on_notice_to}")

  # Step 6: Ensure the entry does not already exist before inserting
    existing_entry = db.execute("SELECT * FROM huon_valley WHERE council_reference = ?", council_reference )

  if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Step 5: Insert the data into the database
  db.execute("INSERT INTO huon_valley (council_reference, description, documents, date_received, on_notice_to, date_scraped) VALUES (?, ?, ?, ?, ?, ?, ?)",
             [council_reference, description, documents_link, date_received, on_notice_to, date_scraped])

  logger.info("Data for #{council_reference} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end
end

# Finish
logger.info("Data has been successfully inserted into the database.")
