{assert} = require 'chai'
{EventEmitter} = require 'events'
proxyquire = require 'proxyquire'
nock = require 'nock'
sinon = require 'sinon'
loggerStub = require '../../../src/logger'

ApiaryReporter = proxyquire '../../../src/reporters/apiary-reporter', {
  './../logger': loggerStub
}

describe 'ApiaryReporter', () ->
  beforeEach () ->
    sinon.stub loggerStub, 'info'
    sinon.stub loggerStub, 'complete'

  afterEach () ->
    sinon.stub loggerStub.info.restore()
    sinon.stub loggerStub.complete.restore()

  describe 'without API key or without suite', () ->
    stats = {}
    tests = []
    test = {}
    emitter = {}
    baseReporter = {}

    beforeEach (done) ->
      stats =
        tests: 0
        failures: 0
        errors: 0
        passes: 0
        skipped: 0
        start: 0
        end: 0
        duration: 0
      tests = []
      emitter = new EventEmitter
      #baseReporter = new BaseReporter(emitter, stats, tests)

      process.env['APIARY_API_URL'] = "https://api.apiary.io"
      delete process.env['APIARY_API_KEY']
      delete process.env['APIARY_API_NAME']

      test =
        status: "fail"
        title: "POST /machines"
        message: "headers: Value of the ‘content-type’ must be application/json.\nbody: No validator found for real data media type 'text/plain' and expected data media type 'application/json'.\nstatusCode: Real and expected data does not match.\n"
        actual:
          statusCode: 400
          headers:
            "content-type": "text/plain"

          body: "Foo bar"

        expected:
          headers:
            "content-type": "application/json"

          body: "{\n  \"type\": \"bulldozer\",\n  \"name\": \"willy\",\n  \"id\": \"5229c6e8e4b0bd7dbb07e29c\"\n}\n"
          status: "202"

        request:
          body: "{\n  \"type\": \"bulldozer\",\n  \"name\": \"willy\"}\n"
          headers:
            "Content-Type": "application/json"
            "User-Agent": "Dredd/0.2.1 (Darwin 13.0.0; x64)"
            "Content-Length": 44

          uri: "/machines"
          method: "POST"

        results:
          headers:
            results: [
              pointer: "/content-type"
              severity: "error"
              message: "Value of the ‘content-type’ must be application/json."
            ]
            realType: "application/vnd.apiary.http-headers+json"
            expectedType: "application/vnd.apiary.http-headers+json"
            validator: "HeadersJsonExample"
            rawData:
              0:
                property: ["content-type"]
                propertyValue: "text/plain"
                attributeName: "enum"
                attributeValue: ["application/json"]
                message: "Value of the ‘content-type’ must be application/json."
                validator: "enum"
                validatorName: "enum"
                validatorValue: ["application/json"]

              length: 1

          body:
            results: [
              message: "No validator found for real data media type 'text/plain' and expected data media type 'application/json'."
              severity: "error"
            ]
            realType: "text/plain"
            expectedType: "application/json"
            validator: null
            rawData: null

          statusCode:
            realType: "text/vnd.apiary.status-code"
            expectedType: "text/vnd.apiary.status-code"
            validator: "TextDiff"
            rawData: "@@ -1,3 +1,9 @@\n-400\n+undefined\n"
            results: [
              severity: "error"
              message: "Real and expected data does not match."
            ]

      nock.disableNetConnect()

      done()

    afterEach (done) ->
      nock.enableNetConnect()
      nock.cleanAll()
      done()

    describe 'when starting', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'

      beforeEach () ->
        uri = '/apis/public/tests/runs'
        reportUrl = "https://absolutely.fency.url/wich-can-change/some/id"
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          reply(201, {"_id": runId, "reportUrl": reportUrl})

      it 'should set uuid', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.uuid
          done()

      it 'should set start time', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.startedAt
          done()

      it 'should call "create new test run" HTTP resource', (done ) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isTrue call.isDone()
          done()

      it 'should attach test run ID back to the reporter as remoteId', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.remoteId
          done()

      it 'should attach test run reportUrl to the reporter as reportUrl', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.reportUrl
          done()

    describe 'when adding passing test', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'
      test = null

      beforeEach () ->
        uri = '/apis/public/tests/steps?testRunId=' + runId
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          reply(201, {"_id": runId})

      it 'should call "create new test step" HTTP resource', () ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'test pass', test
        assert.isTrue call.isDone()

    describe 'when adding failing test', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'
      test = null

      beforeEach () ->
        uri = '/apis/public/tests/steps?testRunId=' + runId
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          reply(201, {"_id": runId})

      it 'should call "create new test step" HTTP resource', () ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'test fail', test
        assert.isTrue call.isDone()


    describe 'when ending', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'

      beforeEach () ->
        uri = '/apis/public/tests/run/' + runId
        call = nock(process.env['APIARY_API_URL']).
          patch(uri).
          reply(201, {"_id": runId})

      it 'should update "test run" resource with result data', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'end', () ->
          assert.isTrue call.isDone()
          done()

      it 'should return generated url if no reportUrl is not available', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'end', () ->
          assert.ok loggerStub.complete.calledWith 'See results in Apiary at: https://app.apiary.io/public/tests/run/507f1f77bcf86cd799439011'
          done()

      it 'should return reportUrl from testRun entity', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        apiaryReporter.reportUrl = "https://absolutely.fency.url/wich-can-change/some/id"
        emitter.emit 'end', () ->
          assert.ok loggerStub.complete.calledWith 'See results in Apiary at: https://absolutely.fency.url/wich-can-change/some/id'
          done()

  describe 'with Apiary API token and suite id', () ->
    stats = {}
    tests = []
    test = {}
    emitter = {}
    baseReporter = {}

    beforeEach (done) ->
      stats =
        tests: 0
        failures: 0
        errors: 0
        passes: 0
        skipped: 0
        start: 0
        end: 0
        duration: 0
      tests = []
      emitter = new EventEmitter
      #baseReporter = new BaseReporter(emitter, stats, tests)

      process.env['APIARY_API_URL'] = "https://api.apiary.io"
      process.env['APIARY_API_KEY'] = "aff888af9993db9ef70edf3c878ab521"
      process.env['APIARY_API_NAME'] = "jakubtest"
      test =
        status: "fail"
        title: "POST /machines"
        message: "headers: Value of the ‘content-type’ must be application/json.\nbody: No validator found for real data media type 'text/plain' and expected data media type 'application/json'.\nstatusCode: Real and expected data does not match.\n"
        actual:
          statusCode: 400
          headers:
            "content-type": "text/plain"

          body: "Foo bar"

        expected:
          headers:
            "content-type": "application/json"

          body: "{\n  \"type\": \"bulldozer\",\n  \"name\": \"willy\",\n  \"id\": \"5229c6e8e4b0bd7dbb07e29c\"\n}\n"
          status: "202"

        request:
          body: "{\n  \"type\": \"bulldozer\",\n  \"name\": \"willy\"}\n"
          headers:
            "Content-Type": "application/json"
            "User-Agent": "Dredd/0.2.1 (Darwin 13.0.0; x64)"
            "Content-Length": 44

          uri: "/machines"
          method: "POST"

        results:
          headers:
            results: [
              pointer: "/content-type"
              severity: "error"
              message: "Value of the ‘content-type’ must be application/json."
            ]
            realType: "application/vnd.apiary.http-headers+json"
            expectedType: "application/vnd.apiary.http-headers+json"
            validator: "HeadersJsonExample"
            rawData:
              0:
                property: ["content-type"]
                propertyValue: "text/plain"
                attributeName: "enum"
                attributeValue: ["application/json"]
                message: "Value of the ‘content-type’ must be application/json."
                validator: "enum"
                validatorName: "enum"
                validatorValue: ["application/json"]

              length: 1

          body:
            results: [
              message: "No validator found for real data media type 'text/plain' and expected data media type 'application/json'."
              severity: "error"
            ]
            realType: "text/plain"
            expectedType: "application/json"
            validator: null
            rawData: null

          statusCode:
            realType: "text/vnd.apiary.status-code"
            expectedType: "text/vnd.apiary.status-code"
            validator: "TextDiff"
            rawData: "@@ -1,3 +1,9 @@\n-400\n+undefined\n"
            results: [
              severity: "error"
              message: "Real and expected data does not match."
            ]

      nock.disableNetConnect()
      done()

    afterEach (done) ->
      nock.enableNetConnect()
      nock.cleanAll()
      done()

    describe 'when starting', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'
      reportUrl = "https://absolutely.fency.url/wich-can-change/some/id"

      beforeEach () ->
        uri = '/apis/' + process.env['APIARY_API_NAME'] + '/tests/runs'
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          matchHeader('Authentication', 'Token ' + process.env['APIARY_API_KEY']).
          reply(201, {"_id": runId, "reportUrl": reportUrl})

      it 'should set uuid', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.uuid
          done()

      it 'should set start time', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.startedAt
          done()

      it 'should call "create new test run" HTTP resource', (done ) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isTrue call.isDone()
          done()

      it 'should attach test run ID back to the reporter as remoteId', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.remoteId
          done()

      it 'should attach test run reportUrl to the reporter as reportUrl', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        emitter.emit 'start', "blueprint data", () ->
          assert.isNotNull apiaryReporter.reportUrl
          done()


    describe 'when adding passing test', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'
      test = null

      beforeEach () ->
        uri = '/apis/' + process.env['APIARY_API_NAME'] + '/tests/steps?testRunId=' + runId
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          matchHeader('Authentication', 'Token ' + process.env['APIARY_API_KEY']).
          reply(201, {"_id": runId})

      it 'should call "create new test step" HTTP resource', () ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'test pass', test
        assert.isTrue call.isDone()

    describe 'when adding failing test', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'
      test = null

      beforeEach () ->
        uri = '/apis/' + process.env['APIARY_API_NAME'] + '/tests/steps?testRunId=' + runId
        call = nock(process.env['APIARY_API_URL']).
          post(uri).
          matchHeader('Authentication', 'Token ' + process.env['APIARY_API_KEY']).
          reply(201, {"_id": runId})

      it 'should call "create new test step" HTTP resource', () ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'test fail', test
        assert.isTrue call.isDone()


    describe 'when ending', () ->
      call = null
      runId = '507f1f77bcf86cd799439011'

      beforeEach () ->
        uri = '/apis/' + process.env['APIARY_API_NAME'] + '/tests/run/' + runId
        call = nock(process.env['APIARY_API_URL']).
          patch(uri).
          matchHeader('Authentication', 'Token ' + process.env['APIARY_API_KEY']).
          reply(201, {"_id": runId})

      it 'should update "test run" resource with result data', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'end', () ->
          assert.isTrue call.isDone()
          done()

      it 'should return generated url if reportUrl is not available', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        emitter.emit 'end', () ->
          assert.ok loggerStub.complete.calledWith 'See results in Apiary at: https://app.apiary.io/jakubtest/tests/run/507f1f77bcf86cd799439011'
          done()

      it 'should return reportUrl from testRun entity', (done) ->
        emitter = new EventEmitter
        apiaryReporter = new ApiaryReporter emitter, {}, {}
        apiaryReporter.remoteId = runId
        apiaryReporter.reportUrl = "https://absolutely.fency.url/wich-can-change/some/id"
        emitter.emit 'end', () ->
          assert.ok loggerStub.complete.calledWith 'See results in Apiary at: https://absolutely.fency.url/wich-can-change/some/id'
          done()
