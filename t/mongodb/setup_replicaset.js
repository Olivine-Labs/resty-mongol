config = {
  _id: 'testset', members: [
    {
      _id: 0,
      host: '127.0.0.1:27017',
      priority: 1
    },
    {
      _id: 1,
      host: '127.0.0.1:27018',
      priority: 0
    },
    {
      _id: 2,
      host: '127.0.0.1:27019',
      priority: 0
    }
  ]
}
rs.initiate(config)
