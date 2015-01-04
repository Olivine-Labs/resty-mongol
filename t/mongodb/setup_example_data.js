db.test_external.insert({
  item: "ABC1",
  details: {
    model: "14Q3",
    manufacturer: "XYZ Company"
  },
  stock: [ { size: "S", qty: 25 }, { size: "M", qty: 50 }, { size: "L", qty: 75 } ],
  tags: [ "a", "b", "c" ],
  category: "clothing",
  hash: {
    0: "AA",
    1: "BB",
    2: "CC",
  }
})
