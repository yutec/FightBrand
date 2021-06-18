# to be run on all nodes

function sayhello()
   println("hi I am worker number $(myid()), I live on $(gethostname())")
end
flush(stdout)
