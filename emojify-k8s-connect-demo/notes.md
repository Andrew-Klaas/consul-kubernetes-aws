## Beforehand:

 - Ensure all workloads spun down
   - kubectl delete -f emojify
   - kubectl delete -f emojify-connect
   - kubectl delete -f emojify-enterprise
   - helm delete --purge consul
   # Delete Consul synched services
   - kubectl delete service --all
   - kubectl delete PersistentVolume --all
   - payments: stop

 - Terminal tab 1
   - cd /Users/banks/src/go/src/github.com/hashicorp/consul-helm
   - doitlive play session.sh

 - Terminal tab 2
   - cd /Users/banks/Documents/Presentations/k8s-envoy-demo
   - doitlive play session.sh

 - Terminal tab 3
   - ssh payments
   - doitlive play session.sh

 - Browser tab 1
   - Cluster: https://console.cloud.google.com/kubernetes/list?organizationId=622235425790&project=consul-k8s-demo-219514&supportedpurview=project
 - Browser tab 2
   - https://ksassets.timeincuk.net/wp/uploads/sites/55/2014/10/2014SClub7_Getty103340379221014.jpg

 - REOPEN SSH session and check can type!!

## Intro

Hi I'm Paul and I'm an engineer on the Consul team.

I want to today about some of the new features we've built in Consul for
connecting services, but I also want to talk about our recent work integrating
deeply with Kubernetes.

Before we get into the details, I want to do a super-quick three minute summary
of the problem space here to set the scene. If this is new to you and you want a
bit more depth on this then I recommend watching Armon and Mitchell's Keynote
from HashiDays Amsterdam back in May where we announced Connect. There are other
great resources around too, there is a great talk by Matt Klein the author of
Envoy proxy I think at @scale this year about why Lyft built it in the first
place and what problems it solved for them.

So this is service mesh in a nutshell.

# Slide 2

The big picture we are assuming here should be no surprise to any one but it's
worth calling out the root of the problem.

Over the last decade at least the trend is for workloads to become more dynamic.
That typically means more of them, living shorter times and being much more
flexible deployed by increasingly sophisticated automation.

I suspect this audience is already more or less sold on why this is the trend
and the good things we get from it like increased developer agility, better
resource utilization etc, but let's look at some of the challenges this brings
for service communication.

## Slide 3

The three core challenges can be broken down into:

**Service Discovery**: how do I find a possible instance of a service to connect to?
Old solutions like fixed IPs or manually curated DNS records don't work in a
scheduler environment.

**Service Segmentation**: how do you keep different workloads secure from each
other? Manually setting up VLANs and configuring firewalls becomes a serious
challenge.

**Configuration**: now you have distributed service instances that might be
anywhere in your cluster, how do you keep their config consistent and have them
pick up changes reliably and quickly?

Spoiler alert, these are all things Consul can help you with!

# Slide 4

The idea of a "Service Mesh" is one particular way to deal with these problems.
People have been solving them in different ways for a long time for example
Twitter's finagle was OpenSourced in 2011 and provided a library/framework based
solution to solve a lot of these problems inside each service.

There are also many Software Defined Networking solutions that solve some
of the three challenges I've mentioned there.

Service Mesh though tends to refer to a separate infrastructure layer that's
between the network and the application. It typically means running a network
proxy process co-located with each application process - we call this pattern a
"sidecar". The benefit of a separate process is separation of concerns.
Operations or SRE teams can upgrade and reconfigure the service communication
completely independently from application - with the built-in library approach
changes to the service communication require coordinating new builds with every
server team.

Just like finagle, the value here is that the Service Mesh layer can implement
all the subtle best-practices for resilient service communication: load
balancing, circuit breakers, retries and so on. We don't have to re-invent all
of those wheels -- which by the way are really hard to test properly -- in every
service code base or build new libraries for each language supported.

But this layer can do more - it can provide consistent instrumentation about the
calls and errors between services without each service team having to instrument
that explicitly in in some common format.

And the configuration is centralized too making it easier to automate and
collaborate on between service teams.

# Slide 5

It's also important to recognize two separate components in a Service Mesh.
There is the Control Plane which is a distributed system that manages state and
broadcasts updates to the endpoints where they are needed. Consul is an example
of a control plane.

Then there is the data plane which is where actual service traffic flows. Consul
Connect makes this component pluggable and currently has both a built in proxy
for easy testing and simple requirements, and now as of a few weeks ago
integrates with Envoy which is a robust, feature-rich and performant proxy for
production.

# Slide 6

So that's Service Mesh in a nutshell. I want to talk about Kubernetes now. I'm
going to assume most people have at least a high-level familiarity with
Kubernetes at this point in the interest of time. But it's a scheduler that will
run your container-based workloads in groups called Pods across a cluster of
machines.

The first thing you might ask is "doesn't Kube already solve those three
problems". Well for discovery and config yes it has good options built in. For
Segmentation it has NetworkPolicies but you do need to use a controller like
calico that actually takes care of enforcement.

But it only solves those problems for your workloads that are in Kubernetes.

We work with a lot of the largest organisations in the world and even those who
are making big bets on kubernetes and have more workloads migrating there, all
recognise some stuff they'll just never be moving. There are many reasons and
some will be fixed over time but some just won't. Most companies of a certain
size also just have to much heterogeneity in their teams, partly through size
and different teams making different choices but also through mergers and
aquisitions and so on.

# Slide 7

We want Consul to work for all out users and customers on whatever platforms
they choose or are lumbered with and work well for the current reality and
brown-field work as well as the shiny new endeavors on the cutting edge.

# Slide 8

But I don't want to sound down on Kube: I think it's fantastic and a really
important part of the future of infrastructure which is why we've spent a lot of
time recently building first class support for Consul on Kubernetes.

Most of the rest of the talk now is going to hopefully be a live demo of a whole
bunch of things. Before I do that though I want to set the scene for what we are
looking at later.

A few weeks ago we release our official Consul Helm chart for installing and
managing Consul in Kubernetes. We're going to use it in a minute to install
Consul on real Kubernetes cluster in a real cloud but let's just look at what it
will look like.

# Slide 9

Our kube cluster is going to have five nodes. Just like in a normal datacenter
deployment we'll install a consul client agent onto every host. We'll also
install 3 consul servers. Note that we end up with both client and server on
three of the nodes just due to a limitation in Kube currently, it's not
necessary generally but it doesn't matter.

Notice there is one client _per node_ though, we don't recommend injecting
client agents directly into every pod. Application pods can talk to the local
client agent using the hostIP kube can expose if needed to register etc.

# Slide 10

OK so enough slides. Let's see this for real.

## Demo


```

$ cat values.dev.yaml

$ helm install -f values.dev.yaml --name consul ./

```

 - Show workloads in UI
 - Show services, when ready, click UI
 - Show consul-ui service and mention Sync from Kube
 - Switch back to presentation for App slide
 - Switch to demo dir terminal

```
$ tree emojify
# Note: this is NOT going to have Connect enabled

$ kubectl apply -f ./emojify
```

 - Show workloads and services
 - Show App
 - Paste image URL from other browser window
 - Submit and watch it work!

 - Now we are going to add connect proxies to secure all the traffic between
   these services.

```
$ tree emojify-connect

$ git diff --no-index -- emojify/api.yml emojify-connect/api.yml

$ kubectl apply -f ./emojify-connect
```

 - Show workloads and services
 - Show App working
 - Add intention to Consul UI: emojify-ingress -> emojify-website DENY
 - Shift reload app
 - Delete intention
 - Reload app

 - Switch to payments slide
 - Switch back to terminal 3

```
$ headlog

$ start
```

 - Show consul UI with payment service (hopefully)
 - Show Kube services with payment service
 - Terminal 2

```
$ git diff --no-index -- emojify-connect/api.yml emojify-enterprise/api.yml

$ kubectl apply -f ./emojify-enterprise
```
