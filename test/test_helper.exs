ExUnit.start()

# Set up Mox
Mox.defmock(CouchbaseEx.PortManagerMock, for: CouchbaseEx.PortManagerBehaviour)
Mox.defmock(CouchbaseEx.ClientMock, for: CouchbaseEx.ClientBehaviour)
